import { LoginService, PrivateService, UsersService } from "../../src/client"
import { createClient } from "../../src/client/client"
import { firstSuperuser, firstSuperuserPassword } from "../config"

/**
 * Tạo client riêng đã xác thực bằng tài khoản Superuser.
 * Không thay đổi client dùng chung của các bài kiểm thử.
 */
const createSuperuserClient = async () => {
  const adminClient = createClient({
    baseURL: `${process.env.VITE_API_URL}`,
    throwOnError: true,
  })

  // Đăng nhập bằng Superuser hiện có.
  const loginResponse = await LoginService.loginAccessToken({
    client: adminClient,
    body: {
      username: firstSuperuser,
      password: firstSuperuserPassword,
    },
  })

  const accessToken = loginResponse.data.access_token

  if (!accessToken) {
    throw new Error("Không lấy được access token của Superuser.")
  }

  // Gắn token vào client riêng.
  adminClient.setConfig({
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  })

  // Xác minh tài khoản thực sự là Superuser.
  const userResponse = await UsersService.readUserMe({
    client: adminClient,
  })

  const superuser = userResponse.data

  if (
    superuser.is_superuser !== true ||
    superuser.role_name !== "admin" ||
    !superuser.role_id
  ) {
    throw new Error(
      "Tài khoản kiểm thử không có quyền Superuser hoặc không có role_id Admin.",
    )
  }

  return {
    adminClient,
    superuser,
  }
}

/**
 * Tạo tài khoản Visitor bằng Private API.
 * Endpoint yêu cầu quyền Superuser.
 */
export const createUser = async ({
  email,
  password,
}: {
  email: string
  password: string
}) => {
  const { adminClient } = await createSuperuserClient()

  const response = await PrivateService.createUser({
    client: adminClient,
    body: {
      email,
      password,
      full_name: "Test User",
    },
  })

  return response.data
}

/**
 * Tạo tài khoản Admin phục vụ kiểm thử phân quyền.
 *
 * Quy trình:
 * 1. Đăng nhập bằng Superuser.
 * 2. Tạo tài khoản Visitor qua Private API.
 * 3. Gán role Admin nhưng giữ is_superuser = false.
 * 4. Đăng nhập tài khoản mới và xác minh quyền Admin.
 */
export const createAdminUser = async ({
  email,
  password,
}: {
  email: string
  password: string
}) => {
  const { adminClient, superuser } = await createSuperuserClient()

  // 1. Tạo tài khoản Visitor trước.
  const createdUser = await PrivateService.createUser({
    client: adminClient,
    body: {
      email,
      password,
      full_name: "Test User",
    },
  })

  if (!createdUser.data?.id) {
    throw new Error("Không thể tạo tài khoản Visitor để nâng quyền Admin.")
  }

  // 2. Gán role Admin, tuyệt đối không bật is_superuser.
  await UsersService.updateUser({
    client: adminClient,
    path: {
      user_id: createdUser.data.id,
    },
    body: {
      role_id: superuser.role_id,
      is_superuser: false,
    },
  })

  // 3. Đăng nhập tài khoản vừa tạo.
  const adminLogin = await LoginService.loginAccessToken({
    client: adminClient,
    body: {
      username: email,
      password,
    },
  })

  const adminToken = adminLogin.data.access_token

  if (!adminToken) {
    throw new Error("Không lấy được access token của tài khoản Admin.")
  }

  adminClient.setConfig({
    headers: {
      Authorization: `Bearer ${adminToken}`,
    },
  })

  // 4. Xác minh quyền thực tế thông qua GET /users/me.
  const adminResponse = await UsersService.readUserMe({
    client: adminClient,
  })

  const admin = adminResponse.data

  if (admin.role_name !== "admin" || admin.is_superuser !== false) {
    throw new Error(
      `Xác minh Admin thất bại: role_name=${admin.role_name}, is_superuser=${admin.is_superuser}.`,
    )
  }

  return admin
}
