import { createFileRoute, useNavigate } from "@tanstack/react-router"
import { ShieldX } from "lucide-react"
import { useQueryClient } from "@tanstack/react-query"

export const Route = createFileRoute("/forbidden")({
  component: Forbidden,
  head: () => ({
    meta: [{ title: "Access Denied - Smart Heritage" }],
  }),
})

function Forbidden() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const handleBackToSignIn = async () => {
    // Xóa token của tài khoản không có quyền Admin
    localStorage.removeItem("access_token")

    // Xóa dữ liệu người dùng đã lưu trong React Query
    queryClient.clear()

    // Chuyển về trang đăng nhập
    await navigate({
      to: "/login",
      replace: true,
    })
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background p-6">
      <div className="flex max-w-md flex-col items-center gap-4 text-center">
        <ShieldX className="size-16 text-destructive" />

        <h1 className="text-5xl font-bold">403</h1>

        <h2 className="text-xl font-semibold">
          Access Denied
        </h2>

        <p className="text-sm text-muted-foreground">
          You do not have permission to access the Smart Heritage
          Administration Console.
        </p>

        <button
          type="button"
          onClick={handleBackToSignIn}
          className="rounded-md bg-primary px-5 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
        >
          Back to Sign In
        </button>
      </div>
    </main>
  )
}
