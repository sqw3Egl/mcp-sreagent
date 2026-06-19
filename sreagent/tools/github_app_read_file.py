"""GitHub App-backed read-only file fetch tool.

This version removes secret-bearing environment variables.
It fetches the GitHub App private key from Azure Key Vault using managed identity.

Supported call styles:
- Portal-style named parameters: main(org, repo, path, appId, ...)
- Legacy wrapper-style object: main({"org": ..., "repo": ..., ...})

Required call parameters:
- org
- repo
- path
- appId

Optional call parameters:
- ref
- maxBytes
- failOnTruncate
- includeMetadata
- keyVaultName
- keyVaultSecretName
- keyVaultSecretVersion
- managedIdentityClientId
- installationMode
- installationId
- allowedOrgs
- allowedRepos
- allowedPathPrefixes
- blockBinaryFiles
- redactSecretsInErrors
"""

import base64
import json
import mimetypes
import posixpath
import time
import urllib.error
import urllib.parse
import urllib.request


MAX_HARD_LIMIT = 1024 * 1024
DEFAULT_MAX_FILE_BYTES = 262144
DEFAULT_BLOCK_BINARY_FILES = True
DEFAULT_REDACT_SECRETS_IN_ERRORS = True
DEFAULT_INSTALLATION_MODE = "auto"
DEFAULT_KEY_VAULT_NAME = "uks-keyvault-kv"
DEFAULT_KEY_VAULT_SECRET_NAME = "github-app-private-key-pem"
DEFAULT_ALLOWED_ORGS = {"sqw3Egl"}
SECRETS_TO_REDACT = []


class ToolError(Exception):
    def __init__(self, code, message, retryable=False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


def _remember_secret(value):
    if isinstance(value, str) and value and value not in SECRETS_TO_REDACT:
        SECRETS_TO_REDACT.append(value)


def _to_bool(value, default=False):
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "yes", "on")
    return default


def _to_string_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str):
        return [item.strip() for item in value.split(",") if item.strip()]
    return [str(value).strip()] if str(value).strip() else []


def _result_error(code, message, retryable=False, redact_secrets=True):
    if redact_secrets:
        for secret_value in SECRETS_TO_REDACT:
            if secret_value:
                message = message.replace(secret_value, "<redacted>")
    return {"code": code, "message": message, "retryable": retryable}


def _b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _normalize_path(path):
    if not isinstance(path, str) or not path.strip():
        raise ToolError("path_not_allowed", "path must be a non-empty string")

    normalized = posixpath.normpath("/" + path.lstrip("/")).lstrip("/")
    if normalized in ("", ".", "..") or normalized.startswith("../") or "/../" in normalized:
        raise ToolError("path_not_allowed", "path must resolve to a repository-relative file path")
    return normalized


def _is_allowed_org(org, allowed_orgs):
    return bool(allowed_orgs) and org in allowed_orgs


def _is_allowed_repo(org, repo, allowed_repos):
    if not allowed_repos:
        return True
    return f"{org}/{repo}" in allowed_repos or repo in allowed_repos


def _is_allowed_path(path, allowed_path_prefixes):
    if not allowed_path_prefixes:
        return True
    normalized_prefixes = [prefix.rstrip("/") for prefix in allowed_path_prefixes if prefix.strip()]
    return any(path == prefix or path.startswith(prefix + "/") for prefix in normalized_prefixes)


def _guess_content_type(path):
    content_type, _ = mimetypes.guess_type(path)
    return content_type or "text/plain"


def _looks_binary(raw_bytes):
    if not raw_bytes:
        return False
    if b"\x00" in raw_bytes:
        return True
    sample = raw_bytes[:1024]
    non_text = sum(1 for b in sample if b < 9 or (13 < b < 32))
    return non_text > max(8, len(sample) // 10)


def _http_json(method, url, headers, body=None):
    request_body = None
    if body is not None:
        request_body = json.dumps(body).encode("utf-8")
        headers = dict(headers)
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=request_body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            payload = json.loads(raw.decode("utf-8")) if raw else {}
            return resp.status, payload, dict(resp.headers)
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        payload = {}
        if raw:
            try:
                payload = json.loads(raw.decode("utf-8"))
            except Exception:
                payload = {"message": raw.decode("utf-8", errors="replace")}
        return exc.code, payload, dict(exc.headers)
    except urllib.error.URLError as exc:
        raise ToolError("internal_error", f"Network error calling remote service: {exc}", retryable=True)


def _get_managed_identity_token(resource, managed_identity_client_id=None):
    query = {
        "api-version": "2018-02-01",
        "resource": resource,
    }
    if managed_identity_client_id:
        query["client_id"] = managed_identity_client_id

    url = "http://169.254.169.254/metadata/identity/oauth2/token?" + urllib.parse.urlencode(query)
    headers = {"Metadata": "true"}
    status, payload, _ = _http_json("GET", url, headers)

    if status == 200 and payload.get("access_token"):
        token = payload["access_token"]
        _remember_secret(token)
        return token
    if status in (400, 401, 403):
        raise ToolError("keyvault_access_denied", payload.get("error_description", "Managed identity token request failed"))
    raise ToolError("internal_error", payload.get("error_description", "Failed to acquire managed identity token"), retryable=status >= 500)


def _get_key_vault_secret(vault_name, secret_name, secret_version=None, managed_identity_client_id=None):
    token = _get_managed_identity_token("https://vault.azure.net", managed_identity_client_id)
    version_segment = f"/{urllib.parse.quote(secret_version, safe='')}" if secret_version else ""
    url = (
        f"https://{vault_name}.vault.azure.net/secrets/"
        f"{urllib.parse.quote(secret_name, safe='')}{version_segment}?api-version=7.4"
    )
    headers = {"Authorization": f"Bearer {token}"}
    status, payload, _ = _http_json("GET", url, headers)

    if status == 200 and payload.get("value"):
        secret_value = payload["value"].replace("\\n", "\n")
        _remember_secret(secret_value)
        return secret_value
    if status in (401, 403):
        raise ToolError("keyvault_access_denied", payload.get("error", {}).get("message", "Access denied to Key Vault secret"))
    if status == 404:
        raise ToolError("internal_error", f"Key Vault secret '{secret_name}' was not found")
    raise ToolError("internal_error", "Failed to read Key Vault secret", retryable=status >= 500)


def _build_app_jwt(app_id, private_key_pem):
    if not app_id:
        raise ToolError("access_denied", "appId is required")

    now = int(time.time())
    payload = {"iat": now - 60, "exp": now + 540, "iss": str(app_id)}

    try:
        import jwt  # type: ignore

        token = jwt.encode(payload, private_key_pem, algorithm="RS256")
        jwt_value = token.decode("utf-8") if isinstance(token, bytes) else token
        _remember_secret(jwt_value)
        return jwt_value
    except Exception:
        pass

    try:
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import padding

        header = {"alg": "RS256", "typ": "JWT"}
        signing_input = (
            f"{_b64url(json.dumps(header, separators=(',', ':')).encode('utf-8'))}."
            f"{_b64url(json.dumps(payload, separators=(',', ':')).encode('utf-8'))}"
        ).encode("ascii")
        private_key = serialization.load_pem_private_key(private_key_pem.encode("utf-8"), password=None)
        signature = private_key.sign(signing_input, padding.PKCS1v15(), hashes.SHA256())
        jwt_value = f"{signing_input.decode('ascii')}.{_b64url(signature)}"
        _remember_secret(jwt_value)
        return jwt_value
    except Exception as exc:
        raise ToolError(
            "internal_error",
            "GitHub App JWT signing requires PyJWT or cryptography in the Python runtime: " + str(exc),
        )


def _app_headers(app_jwt):
    return {
        "Authorization": f"Bearer {app_jwt}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "azure-sre-agent-custom-tool/github_app_read_file",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _installation_headers(token):
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "azure-sre-agent-custom-tool/github_app_read_file",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _resolve_installation_id(org, repo, installation_mode, fixed_installation_id, app_jwt):
    if installation_mode == "fixed":
        if not fixed_installation_id:
            raise ToolError("installation_not_found", "installationId is required when installationMode=fixed")
        return str(fixed_installation_id)

    if installation_mode != "auto":
        raise ToolError("installation_not_found", f"Unsupported installationMode: {installation_mode}")

    repo_url = f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}/installation"
    status, payload, _ = _http_json("GET", repo_url, _app_headers(app_jwt))
    if status == 200 and payload.get("id"):
        return str(payload["id"])

    org_url = f"https://api.github.com/orgs/{urllib.parse.quote(org)}/installation"
    status, payload, _ = _http_json("GET", org_url, _app_headers(app_jwt))
    if status == 200 and payload.get("id"):
        return str(payload["id"])

    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied while resolving GitHub App installation"))
    raise ToolError("installation_not_found", f"No GitHub App installation found for {org}/{repo}")


def _create_installation_token(org, repo, installation_mode, fixed_installation_id, app_jwt):
    installation_id = _resolve_installation_id(org, repo, installation_mode, fixed_installation_id, app_jwt)
    url = f"https://api.github.com/app/installations/{urllib.parse.quote(installation_id)}/access_tokens"
    status, payload, _ = _http_json("POST", url, _app_headers(app_jwt), body={"repositories": [repo]})

    if status in (200, 201) and payload.get("token"):
        token = payload["token"]
        _remember_secret(token)
        return token
    if status == 404:
        raise ToolError("installation_not_found", payload.get("message", "GitHub App installation not found"))
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied creating installation token"))
    raise ToolError("internal_error", payload.get("message", "Failed to create installation token"), retryable=status >= 500)


def _get_repo_metadata(org, repo, token):
    url = f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}"
    status, payload, _ = _http_json("GET", url, _installation_headers(token))

    if status == 404:
        raise ToolError("repo_not_allowed", f"Repository '{org}/{repo}' was not found or is not accessible")
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied to repository metadata"))
    if status >= 500:
        raise ToolError("internal_error", "GitHub repository metadata request failed", retryable=True)
    return payload


def _get_commit_sha(org, repo, ref, token):
    url = f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}/commits/{urllib.parse.quote(ref, safe='')}"
    status, payload, _ = _http_json("GET", url, _installation_headers(token))

    if status == 404:
        raise ToolError("ref_not_found", f"Ref '{ref}' was not found")
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied to commit metadata"))
    if status >= 500:
        raise ToolError("internal_error", "GitHub commit lookup failed", retryable=True)

    sha = payload.get("sha")
    if not sha:
        raise ToolError("internal_error", "Commit SHA missing from GitHub response")
    return sha


def _get_file(org, repo, path, ref, token):
    encoded_path = "/".join(urllib.parse.quote(part, safe="") for part in path.split("/"))
    url = (
        f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}"
        f"/contents/{encoded_path}?ref={urllib.parse.quote(ref, safe='')}"
    )
    status, payload, headers = _http_json("GET", url, _installation_headers(token))

    if status == 404:
        raise ToolError("not_found", f"File '{path}' was not found")
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied to file"))
    if status >= 500:
        raise ToolError("internal_error", "GitHub file request failed", retryable=True)

    if isinstance(payload, list):
        raise ToolError("not_found", "The requested path is a directory, not a file")
    if payload.get("type") != "file":
        raise ToolError("not_found", "The requested path is not a file")
    if payload.get("encoding") != "base64":
        raise ToolError("internal_error", f"Unsupported GitHub content encoding: {payload.get('encoding')}")

    content = payload.get("content", "")
    raw_bytes = base64.b64decode(content.encode("utf-8"))
    return {
        "sizeBytes": int(payload.get("size", 0)),
        "rawBytes": raw_bytes,
        "contentType": _guess_content_type(path),
        "etag": headers.get("ETag"),
    }


def _run(params):
    try:
        org = params["org"]
        repo = params["repo"]
        path = _normalize_path(params["path"])
        app_id = params["appId"]
        ref = params.get("ref")
        max_bytes = int(params.get("maxBytes", DEFAULT_MAX_FILE_BYTES))
        fail_on_truncate = _to_bool(params.get("failOnTruncate"), False)
        include_metadata = _to_bool(params.get("includeMetadata"), True)

        key_vault_name = params.get("keyVaultName", DEFAULT_KEY_VAULT_NAME)
        key_vault_secret_name = params.get("keyVaultSecretName", DEFAULT_KEY_VAULT_SECRET_NAME)
        key_vault_secret_version = params.get("keyVaultSecretVersion")
        managed_identity_client_id = params.get("managedIdentityClientId")

        installation_mode = str(params.get("installationMode", DEFAULT_INSTALLATION_MODE)).strip().lower()
        installation_id = params.get("installationId")

        allowed_orgs = set(_to_string_list(params.get("allowedOrgs"))) or set(DEFAULT_ALLOWED_ORGS)
        allowed_repos = set(_to_string_list(params.get("allowedRepos")))
        allowed_path_prefixes = _to_string_list(params.get("allowedPathPrefixes"))
        block_binary_files = _to_bool(params.get("blockBinaryFiles"), DEFAULT_BLOCK_BINARY_FILES)
        redact_secrets_in_errors = _to_bool(params.get("redactSecretsInErrors"), DEFAULT_REDACT_SECRETS_IN_ERRORS)

        if not _is_allowed_org(org, allowed_orgs):
            raise ToolError("org_not_allowed", f"Organization '{org}' is not allowed")
        if not _is_allowed_repo(org, repo, allowed_repos):
            raise ToolError("repo_not_allowed", f"Repository '{org}/{repo}' is not allowed")
        if not _is_allowed_path(path, allowed_path_prefixes):
            raise ToolError("path_not_allowed", f"Path '{path}' is not allowed")
        if max_bytes < 1 or max_bytes > MAX_HARD_LIMIT:
            raise ToolError("file_too_large", f"maxBytes must be between 1 and {MAX_HARD_LIMIT}")

        private_key_pem = _get_key_vault_secret(
            key_vault_name,
            key_vault_secret_name,
            key_vault_secret_version,
            managed_identity_client_id,
        )
        app_jwt = _build_app_jwt(app_id, private_key_pem)
        installation_token = _create_installation_token(org, repo, installation_mode, installation_id, app_jwt)
        repo_metadata = _get_repo_metadata(org, repo, installation_token)
        resolved_ref = ref or repo_metadata.get("default_branch")
        if not resolved_ref:
            raise ToolError("internal_error", "Repository default branch is missing")

        commit_sha = _get_commit_sha(org, repo, resolved_ref, installation_token)
        file_info = _get_file(org, repo, path, resolved_ref, installation_token)
        raw_bytes = file_info["rawBytes"]

        if block_binary_files and _looks_binary(raw_bytes):
            raise ToolError("binary_file_not_supported", "Binary files are not supported by this tool")

        try:
            decoded = raw_bytes.decode("utf-8")
            encoding = "utf-8"
        except UnicodeDecodeError:
            raise ToolError("binary_file_not_supported", "File content is not valid utf-8 text")

        warnings = []
        truncated = False
        if len(raw_bytes) > max_bytes:
            if fail_on_truncate:
                raise ToolError("file_too_large", f"File exceeds maxBytes limit of {max_bytes}")
            decoded = raw_bytes[:max_bytes].decode("utf-8", errors="ignore")
            truncated = True
            warnings.append(f"Content truncated to {max_bytes} bytes")

        result = {
            "org": org,
            "repo": repo,
            "path": path,
            "ref": resolved_ref,
            "content": decoded,
            "truncated": truncated,
        }

        if include_metadata:
            result["commitSha"] = commit_sha
            result["sizeBytes"] = file_info["sizeBytes"]
            result["contentType"] = file_info["contentType"]
            result["encoding"] = encoding
            if warnings:
                result["warnings"] = warnings

        return result
    except ToolError as exc:
        return _result_error(exc.code, exc.message, exc.retryable, redact_secrets_in_errors)
    except KeyError as exc:
        redact_secrets_in_errors = _to_bool(params.get("redactSecretsInErrors"), DEFAULT_REDACT_SECRETS_IN_ERRORS) if isinstance(params, dict) else DEFAULT_REDACT_SECRETS_IN_ERRORS
        return _result_error("internal_error", f"Missing required input: {exc.args[0]}", redact_secrets=redact_secrets_in_errors)
    except Exception as exc:
        redact_secrets_in_errors = _to_bool(params.get("redactSecretsInErrors"), DEFAULT_REDACT_SECRETS_IN_ERRORS) if isinstance(params, dict) else DEFAULT_REDACT_SECRETS_IN_ERRORS
        return _result_error("internal_error", f"Unexpected error: {exc}", redact_secrets=redact_secrets_in_errors)


def main(
    org,
    repo=None,
    path=None,
    appId=None,
    ref=None,
    maxBytes=DEFAULT_MAX_FILE_BYTES,
    failOnTruncate=False,
    includeMetadata=True,
    keyVaultName=DEFAULT_KEY_VAULT_NAME,
    keyVaultSecretName=DEFAULT_KEY_VAULT_SECRET_NAME,
    keyVaultSecretVersion=None,
    managedIdentityClientId=None,
    installationMode=DEFAULT_INSTALLATION_MODE,
    installationId=None,
    allowedOrgs=None,
    allowedRepos=None,
    allowedPathPrefixes=None,
    blockBinaryFiles=DEFAULT_BLOCK_BINARY_FILES,
    redactSecretsInErrors=DEFAULT_REDACT_SECRETS_IN_ERRORS,
):
    if isinstance(org, dict) and repo is None and path is None and appId is None:
        return _run(org)

    params = {
        "org": org,
        "repo": repo,
        "path": path,
        "appId": appId,
        "ref": ref,
        "maxBytes": maxBytes,
        "failOnTruncate": failOnTruncate,
        "includeMetadata": includeMetadata,
        "keyVaultName": keyVaultName,
        "keyVaultSecretName": keyVaultSecretName,
        "keyVaultSecretVersion": keyVaultSecretVersion,
        "managedIdentityClientId": managedIdentityClientId,
        "installationMode": installationMode,
        "installationId": installationId,
        "allowedOrgs": allowedOrgs,
        "allowedRepos": allowedRepos,
        "allowedPathPrefixes": allowedPathPrefixes,
        "blockBinaryFiles": blockBinaryFiles,
        "redactSecretsInErrors": redactSecretsInErrors,
    }
    return _run(params)
