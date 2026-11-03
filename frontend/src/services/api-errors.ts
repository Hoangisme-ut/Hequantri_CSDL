import { AxiosError } from "axios"

type ApiDetail =
  | string
  | Array<{ loc?: Array<string | number>; msg?: string }>
  | undefined

export function toApiError(error: unknown, resource: string): Error {
  if (!(error instanceof AxiosError)) {
    return error instanceof Error
      ? error
      : new Error(`${resource} request failed.`)
  }

  const status = error.response?.status
  const detail = (error.response?.data as { detail?: ApiDetail } | undefined)
    ?.detail
  const message = Array.isArray(detail)
    ? detail
        .map((issue) => {
          const field = issue.loc?.slice(1).join(".")
          return [field, issue.msg].filter(Boolean).join(": ")
        })
        .filter(Boolean)
        .join("; ")
    : detail

  if (status === 401) {
    localStorage.removeItem("access_token")
    window.location.assign("/login")
    return new Error("Your session has expired. Please sign in again.")
  }
  if (status === 403) {
    return new Error(
      `You do not have permission to manage ${resource.toLowerCase()}.`,
    )
  }
  if (status === 404) {
    return new Error(
      `${resource} or a related record was not found. ${message ?? ""}`.trim(),
    )
  }
  if (status === 409) {
    return new Error(message || `${resource} conflicts with existing data.`)
  }
  if (status === 422) {
    return new Error(
      message || `Some ${resource.toLowerCase()} fields are invalid.`,
    )
  }
  if (status) {
    return new Error(
      `${resource} request failed (${status}): ${message ?? error.message}`,
    )
  }
  return new Error(
    `Cannot reach the ${resource} API. Check that the backend is running. ${error.message}`,
  )
}

export async function unwrapApi<T>(
  request: Promise<{ data: T }>,
  resource: string,
): Promise<T> {
  try {
    return (await request).data
  } catch (error) {
    throw toApiError(error, resource)
  }
}
