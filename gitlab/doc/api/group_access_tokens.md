---
stage: Software Supply Chain Security
group: Authentication
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
title: Group access tokens API
---

DETAILS:
**Tier:** Free, Premium, Ultimate
**Offering:** GitLab.com, GitLab Self-Managed, GitLab Dedicated

Use this API to interact with group access tokens. For more information, see [Group access tokens](../user/group/settings/group_access_tokens.md).

## List all group access tokens

> - `state` attribute [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/462217) in GitLab 17.2.

Lists all group access tokens for a group.

In GitLab 17.2 and later, you can use the `state` attribute to limit the response to group access tokens with a specified state.

```plaintext
GET /groups/:id/access_tokens
GET /groups/:id/access_tokens?state=inactive
```

| Attribute | Type              | required | Description |
| --------- | ----------------- | -------- | ----------- |
| `id`      | integer or string | yes      | ID or [URL-encoded path](rest/_index.md#namespaced-paths) of a group. |
| `state`   | string            | No       | If defined, only returns tokens with the specified state. Possible values: `active` and `inactive`. |

```shell
curl --request GET \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/<group_id>/access_tokens"
```

```json
[
   {
      "user_id" : 141,
      "scopes" : [
         "api"
      ],
      "name" : "token",
      "expires_at" : "2021-01-31",
      "id" : 42,
      "active" : true,
      "created_at" : "2021-01-20T22:11:48.151Z",
      "revoked" : false,
      "last_used_at": null,
      "access_level": 40
   },
   {
      "user_id" : 141,
      "scopes" : [
         "read_api"
      ],
      "name" : "token-2",
      "expires_at" : "2021-01-31",
      "id" : 43,
      "active" : false,
      "created_at" : "2021-01-21T12:12:38.123Z",
      "revoked" : true,
      "last_used_at": "2021-02-13T10:34:57.178Z",
      "access_level": 40
   }
]
```

## Get details on a group access token

Gets details on a group access token. You can reference a specific group access token, or use the keyword `self` to return details on the authenticating group access token.

```plaintext
GET /groups/:id/access_tokens/:token_id
```

| Attribute  | Type              | required | Description |
| ---------- | ----------------- | -------- | ----------- |
| `id`       | integer or string | yes      | ID or [URL-encoded path](rest/_index.md#namespaced-paths) of a group. |
| `token_id` | integer or string | yes      | ID of a group access token or the keyword `self`. |

```shell
curl --request GET \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/<group_id>/access_tokens/<token_id>"
```

```json
{
   "user_id" : 141,
   "scopes" : [
      "api"
   ],
   "name" : "token",
   "expires_at" : "2021-01-31",
   "id" : 42,
   "active" : true,
   "created_at" : "2021-01-20T22:11:48.151Z",
   "revoked" : false,
   "access_level": 40
}
```

## Create a group access token

> - The `expires_at` attribute default was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/120213) in GitLab 16.0.

Creates a group access token for a specified group.

Prerequisites:

- You must have the Owner role for the group.

```plaintext
POST /groups/:id/access_tokens
```

| Attribute      | Type              | required | Description |
| -------------- | ----------------- | -------- | ----------- |
| `id`           | integer or string | yes      | ID or [URL-encoded path](rest/_index.md#namespaced-paths) of a group. |
| `name`         | String            | yes      | Name of the token. |
| `scopes`       | `Array[String]`   | yes      | List of [scopes](../user/group/settings/group_access_tokens.md#scopes-for-a-group-access-token) available to the token. |
| `access_level` | Integer           | no       | [Access level](../development/permissions/predefined_roles.md#members) for the token. Possible values: `10` (Guest), `15` (Planner), `20` (Reporter), `30` (Developer), `40` (Maintainer), and `50` (Owner). Default value: `40`. |
| `expires_at`   | date              | no       | Expiration date of the access token in ISO format (`YYYY-MM-DD`). The date must be one year or less from the rotation date. If undefined, the date is set to the [maximum allowable lifetime limit](../user/profile/personal_access_tokens.md#access-token-expiration). |

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --header "Content-Type:application/json" \
  --data '{ "name":"test_token", "scopes":["api", "read_repository"], "expires_at":"2021-01-31", "access_level": 30 }' \
  --url "https://gitlab.example.com/api/v4/groups/<group_id>/access_tokens"
```

```json
{
   "scopes" : [
      "api",
      "read_repository"
   ],
   "active" : true,
   "name" : "test",
   "revoked" : false,
   "created_at" : "2021-01-21T19:35:37.921Z",
   "user_id" : 166,
   "id" : 58,
   "expires_at" : "2021-01-31",
   "token" : "D4y...Wzr",
   "access_level": 30
}
```

## Rotate a group access token

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/403042) in GitLab 16.0
> - `expires_at` attribute [added](https://gitlab.com/gitlab-org/gitlab/-/issues/416795) in GitLab 16.6.

Rotates a group access token. This immediately revokes the previous token and creates a new token. Generally, this endpoint rotates a specific group access token by authenticating with a personal access token. You can also use a group access token to rotate itself. For more information, see [Self-rotation](#self-rotation).

If you attempt to use the revoked token later, GitLab immediately revokes the new token. For more information, see [Automatic reuse detection](personal_access_tokens.md#automatic-reuse-detection).

Prerequisites:

- A personal access token with the [`api` scope](../user/profile/personal_access_tokens.md#personal-access-token-scopes) or a group access token with the [`api` or `self_rotate` scope](../user/profile/personal_access_tokens.md#personal-access-token-scopes). See [Self-rotation](#self-rotation).

```plaintext
POST /groups/:id/access_tokens/:token_id/rotate
```

| Attribute    | Type              | required | Description |
| ------------ | ----------------- | -------- | ----------- |
| `id`         | integer or string | yes      | ID or [URL-encoded path](rest/_index.md#namespaced-paths) of a group. |
| `token_id`   | integer or string | yes      | ID of a group access token or the keyword `self`. |
| `expires_at` | date              | no       | Expiration date of the access token in ISO format (`YYYY-MM-DD`). The date must be one year or less from the rotation date. If undefined, the token expires after one week. |

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/<group_id>/access_tokens/<token_id>/rotate"
```

Example response:

```json
{
    "id": 42,
    "name": "Rotated Token",
    "revoked": false,
    "created_at": "2023-08-01T15:00:00.000Z",
    "description": "Test group access token",
    "scopes": ["api"],
    "user_id": 1337,
    "last_used_at": null,
    "active": true,
    "expires_at": "2023-08-15",
    "access_level": 30,
    "token": "s3cr3t"
}
```

If successful, returns `200: OK`.

Other possible responses:

- `400: Bad Request` if not rotated successfully.
- `401: Unauthorized` if any of the following conditions are true:
  - The token does not exist.
  - The token has expired.
  - The token was revoked.
  - You do not have access to the specified token.
  - You're using a group access token to rotate another group access token. See [Self-rotate a project access token](#self-rotation) instead.
- `403: Forbidden` if the token is not allowed to rotate itself.
- `404: Not Found` if the user is an administrator but the token with the specified ID does not exist.
- `405: Method Not Allowed` if the token is not an access token.

### Self-rotation

Instead of rotating a specific group access token, you can instead rotate the same group access token you used to authenticate the request. To self-rotate a group access token, you must:

- Rotate a group access token with the [`api` or `self_rotate` scope](../user/profile/personal_access_tokens.md#personal-access-token-scopes).
- Use the `self` keyword in the request URL.

Example request:

```shell
curl --request POST \
  --header "PRIVATE-TOKEN: <your_group_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/<group_id>/access_tokens/self/rotate"
```

## Revoke a group access token

Revokes a specified group access token.

```plaintext
DELETE /groups/:id/access_tokens/:token_id
```

| Attribute  | Type              | required | Description |
| ---------- | ----------------- | -------- | ----------- |
| `id`       | integer or string | yes      | ID or [URL-encoded path](rest/_index.md#namespaced-paths) of a group. |
| `token_id` | integer           | yes      | ID of a group access token. |

```shell
curl --request DELETE \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/<group_id>/access_tokens/<token_id>"
```

If successful, returns `204 No content`.

Other possible responses:

- `400 Bad Request`: Token was not revoked.
- `404 Not Found`: Token can not be found.
