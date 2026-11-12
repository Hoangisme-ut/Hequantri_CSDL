import { zodResolver } from "@hookform/resolvers/zod"
import { useMutation } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { AxiosError } from "axios"
import {
  CheckCircle2,
  CircleAlert,
  ShieldCheck,
  Smartphone,
} from "lucide-react"
import { useState } from "react"
import { useForm } from "react-hook-form"
import { z } from "zod"

import { LoginService } from "@/client"
import { Logo } from "@/components/Common/Logo"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { LoadingButton } from "@/components/ui/loading-button"
import { PasswordInput } from "@/components/ui/password-input"

const searchSchema = z.object({
  token: z.string().catch(""),
})

const formSchema = z
  .object({
    new_password: z
      .string()
      .min(1, { message: "Vui lòng nhập mật khẩu mới." })
      .min(8, { message: "Mật khẩu cần có ít nhất 8 ký tự." }),
    confirm_password: z
      .string()
      .min(1, { message: "Vui lòng xác nhận mật khẩu mới." }),
  })
  .refine((data) => data.new_password === data.confirm_password, {
    message: "Mật khẩu xác nhận không khớp.",
    path: ["confirm_password"],
  })

type FormData = z.infer<typeof formSchema>

export const Route = createFileRoute("/reset-password")({
  component: ResetPassword,
  validateSearch: searchSchema,
  head: () => ({
    meta: [
      {
        title: "Đặt lại mật khẩu | Smart Heritage",
      },
    ],
  }),
})

function ResetPassword() {
  const { token } = Route.useSearch()
  const [isComplete, setIsComplete] = useState(false)
  const [showReturnInstructions, setShowReturnInstructions] = useState(false)
  const [submitError, setSubmitError] = useState("")

  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      new_password: "",
      confirm_password: "",
    },
  })

  const mutation = useMutation({
    mutationFn: (data: { new_password: string; token: string }) =>
      LoginService.resetPassword({ body: data }),
    onSuccess: () => {
      form.reset()
      setSubmitError("")
      setIsComplete(true)
      // The token is no longer needed after the API accepts it. Remove it from
      // the address bar without redirecting to the Admin login page.
      window.history.replaceState(
        window.history.state,
        "",
        window.location.pathname,
      )
    },
    onError: (error: Error) => {
      setSubmitError(getResetErrorMessage(error))
    },
  })

  const onSubmit = (data: FormData) => {
    if (!token || mutation.isPending) return
    setSubmitError("")
    mutation.mutate({ new_password: data.new_password, token })
  }

  return (
    <ResetPasswordLayout>
      {isComplete ? (
        <ResetSuccess
          showReturnInstructions={showReturnInstructions}
          onReturnClick={() => setShowReturnInstructions(true)}
        />
      ) : !token ? (
        <InvalidResetLink />
      ) : (
        <section className="px-6 py-7 sm:px-9 sm:py-9">
          <div className="mb-7 flex flex-col gap-3">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-[#384CCA]/10 text-[#384CCA]">
              <ShieldCheck aria-hidden="true" className="size-6" />
            </span>
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-[#1E2A5A] sm:text-[28px]">
                Đặt lại mật khẩu
              </h1>
              <p className="mt-2 text-sm leading-6 text-slate-600">
                Tạo mật khẩu mới để tiếp tục khám phá di sản cùng Smart
                Heritage.
              </p>
            </div>
          </div>

          {submitError && (
            <Alert
              variant="destructive"
              className="mb-6 border-red-200 bg-red-50 text-red-800"
            >
              <CircleAlert aria-hidden="true" />
              <AlertTitle>Chưa thể cập nhật mật khẩu</AlertTitle>
              <AlertDescription className="text-red-800">
                {submitError}
              </AlertDescription>
            </Alert>
          )}

          <Form {...form}>
            <form
              onSubmit={form.handleSubmit(onSubmit)}
              className="flex flex-col gap-5"
              noValidate
            >
              <FormField
                control={form.control}
                name="new_password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-semibold text-slate-700">
                      Mật khẩu mới
                    </FormLabel>
                    <FormControl>
                      <PasswordInput
                        data-testid="new-password-input"
                        autoComplete="new-password"
                        placeholder="Nhập mật khẩu mới"
                        disabled={mutation.isPending}
                        className="h-11 rounded-lg focus-visible:border-[#384CCA] focus-visible:ring-[#384CCA]/25"
                        {...field}
                      />
                    </FormControl>
                    <p className="text-xs text-slate-500">Tối thiểu 8 ký tự.</p>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="confirm_password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-semibold text-slate-700">
                      Xác nhận mật khẩu mới
                    </FormLabel>
                    <FormControl>
                      <PasswordInput
                        data-testid="confirm-password-input"
                        autoComplete="new-password"
                        placeholder="Nhập lại mật khẩu mới"
                        disabled={mutation.isPending}
                        className="h-11 rounded-lg focus-visible:border-[#384CCA] focus-visible:ring-[#384CCA]/25"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <LoadingButton
                type="submit"
                loading={mutation.isPending}
                disabled={mutation.isPending}
                className="mt-1 h-11 w-full rounded-lg bg-[#384CCA] text-white hover:bg-[#2E3FAE] focus-visible:ring-[#384CCA]/30"
              >
                Cập nhật mật khẩu
              </LoadingButton>
            </form>
          </Form>

          <p className="mt-6 text-center text-xs leading-5 text-slate-500">
            Liên kết chỉ dùng được một lần. Nếu liên kết đã hết hạn, hãy yêu cầu
            một email khôi phục mới.
          </p>
        </section>
      )}
    </ResetPasswordLayout>
  )
}

function getResetErrorMessage(error: Error): string {
  if (error instanceof AxiosError) {
    if (error.response?.status === 400) {
      return "Liên kết không hợp lệ, đã hết hạn hoặc đã được sử dụng. Hãy yêu cầu email khôi phục mới."
    }
    if (error.response?.status === 422) {
      return "Mật khẩu chưa đáp ứng yêu cầu. Vui lòng kiểm tra lại và thử lại."
    }
    if (!error.response) {
      return "Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối và thử lại."
    }
  }
  return "Đã xảy ra lỗi khi cập nhật mật khẩu. Vui lòng thử lại sau."
}

function ResetPasswordLayout({ children }: { children: React.ReactNode }) {
  return (
    <main className="relative flex min-h-svh items-center justify-center overflow-hidden bg-[#F1F5F9] px-4 py-8 sm:px-6 sm:py-12">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -left-28 -top-32 size-80 rounded-full bg-[#384CCA]/10 blur-3xl"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -bottom-36 -right-24 size-96 rounded-full bg-teal-500/10 blur-3xl"
      />
      <div className="relative w-full max-w-[520px] overflow-hidden rounded-3xl border border-slate-200/80 bg-white shadow-[0_24px_80px_-32px_rgba(30,42,90,0.3)]">
        <header className="bg-[#1E2A5A] px-6 py-5 sm:px-9">
          <Logo asLink={false} />
        </header>
        {children}
      </div>
    </main>
  )
}

function InvalidResetLink() {
  return (
    <section className="px-6 py-9 text-center sm:px-9 sm:py-12">
      <span className="mx-auto mb-5 flex size-14 items-center justify-center rounded-2xl bg-amber-50 text-amber-700">
        <CircleAlert aria-hidden="true" className="size-7" />
      </span>
      <h1 className="text-2xl font-bold tracking-tight text-[#1E2A5A]">
        Liên kết không hợp lệ
      </h1>
      <p className="mx-auto mt-3 max-w-sm text-sm leading-6 text-slate-600">
        Liên kết đặt lại mật khẩu không có mã xác thực. Hãy mở lại liên kết
        trong email hoặc yêu cầu email khôi phục mới.
      </p>
      <a
        href="/recover-password"
        className="mt-7 inline-flex h-11 items-center justify-center rounded-lg bg-[#384CCA] px-6 text-sm font-semibold text-white transition hover:bg-[#2E3FAE] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#384CCA]/25"
      >
        Yêu cầu email mới
      </a>
    </section>
  )
}

function ResetSuccess({
  showReturnInstructions,
  onReturnClick,
}: {
  showReturnInstructions: boolean
  onReturnClick: () => void
}) {
  return (
    <section className="px-6 py-9 text-center sm:px-9 sm:py-12">
      <span className="mx-auto mb-5 flex size-16 items-center justify-center rounded-full bg-emerald-50 text-emerald-700">
        <CheckCircle2 aria-hidden="true" className="size-9" />
      </span>
      <p className="mb-2 text-sm font-semibold uppercase tracking-[0.14em] text-emerald-700">
        Hoàn tất bảo mật
      </p>
      <h1 className="text-2xl font-bold tracking-tight text-[#1E2A5A] sm:text-[28px]">
        Mật khẩu đã được cập nhật!
      </h1>
      <p className="mt-4 text-sm font-semibold text-emerald-800">
        Mật khẩu của bạn đã được cập nhật thành công!
      </p>
      <p className="mx-auto mt-2 max-w-sm text-sm leading-6 text-slate-600">
        Hãy quay lại ứng dụng Smart Heritage và đăng nhập bằng mật khẩu mới.
      </p>

      {showReturnInstructions && (
        <div
          role="status"
          className="mt-6 rounded-xl border border-blue-100 bg-blue-50 p-4 text-left text-sm leading-6 text-[#1E2A5A]"
        >
          <p className="font-semibold">Mở lại Smart Heritage Mobile</p>
          <p className="mt-1">
            Trên điện thoại, hãy mở ứng dụng Smart Heritage từ màn hình chính.
            Nếu bạn đang dùng máy tính, hãy mở ứng dụng trên điện thoại để đăng
            nhập.
          </p>
        </div>
      )}

      <Button
        type="button"
        onClick={onReturnClick}
        className="mt-7 h-11 w-full rounded-lg bg-[#384CCA] text-white hover:bg-[#2E3FAE] focus-visible:ring-[#384CCA]/30"
      >
        <Smartphone aria-hidden="true" className="size-4" />
        Tôi đã hiểu – Quay lại ứng dụng
      </Button>
    </section>
  )
}
