import {
  LoginService,
  PrivateService,
  UsersService,
} from "../../src/client"
import { createClient } from "../../src/client/client"
import { client } from "../../src/client/client.gen"
import {
  firstSuperuser,
  firstSuperuserPassword,
} from "../config"

client.setConfig({
  baseURL: `${process.env.VITE_API_URL}`,
})

/**
 * Tạo tài khoản Visitor bằng Private API.
 * Giữ nguyên hành vi hiện tại để sử dụng trong các bài kiểm thử Visitor.
 */
export const createUser = async ({
  email,
  password,
}: {
  email: string
  password: string
}) => {
  const response = await PrivateService.createUser({
    body: {
      email,
      password,
      is_verified: true,
      full_name: "Test User",
    },
  })
  return response.data
}

/**
 * Tạo tài khoản Admin phục vụ kiểm thử phân quyền.
 * Quy trình:
 * 1. Tạo tài khoản Visitor.
 * 2. Đăng nhập bằng Superuser hiện có.
 * 3. Kiểm tra quyền Superuser và lấy role_id của Admin.
 * 4. Dùng Superuser cập nhật role_id cho tài khoản vừa tạo.
 * 5. Đăng nhập tài khoản mới và xác minh quyền Admin.
 */
export const createAdminUser = async ({
  email,
  password,
}: {
  email: string
  password: string
}) => {
  // 1. Tạo tài khoản Visitor trước.
  const createdUser = await createUser({ email, password })

  if (!createdUser?.id) {
    throw new Error("Không thể tạo tài khoản Visitor để nâng quyền Admin.")
  }

  // Tạo client riêng, không thay đổi client dùng chung.
  const adminClient = createClient({
    baseURL: `${process.env.VITE_API_URL}`,
    throwOnError: true,
  })

  // 2. Đăng nhập bằng Superuser hiện có.
  const superuserLogin = await LoginService.loginAccessToken({
    client: adminClient,
    body: {
      username: firstSuperuser,
      password: firstSuperuserPassword,
    },
  })

  const superuserToken = superuserLogin.data.access_token

  if (!superuserToken) {
    throw new Error("Không lấy được access token của Superuser.")
  }

  adminClient.setConfig({
    headers: {
      Authorization: `Bearer ${superuserToken}`,
    },
  })

  // 3. Xác minh Superuser và lấy role_id Admin.
  const superuserResponse = await UsersService.readUserMe({
    client: adminClient,
  })

  const superuser = superuserResponse.data

  if (
    superuser.is_superuser !== true ||
    superuser.role_name !== "admin" ||
    !superuser.role_id
  ) {
    throw new Error(
      "Tài khoản đăng nhập không có quyền Superuser hoặc không có role_id Admin.",
    )
  }

  // 4. Gán role Admin, tuyệt đối không bật is_superuser.
  await UsersService.updateUser({
    client: adminClient,
    path: {
      user_id: createdUser.id,
    },
    body: {
      role_id: superuser.role_id,
      is_superuser: false,
    },
  })

  // 5. Đăng nhập tài khoản vừa tạo.
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

  // 6. Xác minh quyền thực tế thông qua GET /users/me.
  const adminResponse = await UsersService.readUserMe({
    client: adminClient,
  })

  const admin = adminResponse.data

  if (
    admin.role_name !== "admin" ||
    admin.is_superuser !== false
  ) {
    throw new Error(
      `Xác minh Admin thất bại: role_name=${admin.role_name}, is_superuser=${admin.is_superuser}.`,
    )
  }

  return admin
}
