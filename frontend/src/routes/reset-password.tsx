import { zodResolver } from "@hookform/resolvers/zod"
import { useMutation } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { AxiosError } from "axios"
import {
  Check,
  CheckCircle2,
  CircleAlert,
  Eye,
  EyeOff,
  Landmark,
  LockKeyhole,
  ShieldCheck,
  Smartphone,
} from "lucide-react"
import { useMemo, useState } from "react"
import { useForm } from "react-hook-form"
import { z } from "zod"

import { LoginService } from "@/client"
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
import { cn } from "@/lib/utils"

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
    meta: [{ title: "Đặt lại mật khẩu | Smart Heritage" }],
  }),
})

function ResetPassword() {
  const { token } = Route.useSearch()
  const [isComplete, setIsComplete] = useState(false)
  const [showReturnInstructions, setShowReturnInstructions] = useState(false)
  const [submitError, setSubmitError] = useState("")
  const [invalidToken, setInvalidToken] = useState(false)

  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      new_password: "",
      confirm_password: "",
    },
  })
  const password = form.watch("new_password")
  const strength = useMemo(
    () => getPasswordStrength(password ?? ""),
    [password],
  )

  const mutation = useMutation({
    mutationFn: (data: { new_password: string; token: string }) =>
      LoginService.resetPassword({ body: data }),
    onSuccess: () => {
      form.reset()
      setSubmitError("")
      setIsComplete(true)
      window.history.replaceState(
        window.history.state,
        "",
        window.location.pathname,
      )
    },
    onError: (error: Error) => {
      if (error instanceof AxiosError && error.response?.status === 400) {
        setInvalidToken(true)
        window.history.replaceState(
          window.history.state,
          "",
          window.location.pathname,
        )
        return
      }
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
      ) : invalidToken ? (
        <InvalidResetLink expired />
      ) : !token ? (
        <InvalidResetLink expired={false} />
      ) : (
        <section
          className="px-6 py-7 sm:px-10 sm:py-9"
          aria-labelledby="reset-title"
        >
          <div className="mb-7 flex items-start gap-4">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-[#384CCA]/10 text-[#384CCA]">
              <ShieldCheck aria-hidden="true" className="size-6" />
            </span>
            <div>
              <h1
                id="reset-title"
                className="text-2xl font-bold tracking-tight text-slate-950 sm:text-[28px]"
              >
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
                      <ResetPasswordInput
                        data-testid="new-password-input"
                        autoComplete="new-password"
                        placeholder="Nhập mật khẩu mới"
                        disabled={mutation.isPending}
                        {...field}
                      />
                    </FormControl>
                    <p className="text-xs text-slate-500">Tối thiểu 8 ký tự.</p>
                    <PasswordStrength
                      strength={strength}
                      visible={password.length > 0}
                    />
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
                      <ResetPasswordInput
                        data-testid="confirm-password-input"
                        autoComplete="new-password"
                        placeholder="Nhập lại mật khẩu mới"
                        disabled={mutation.isPending}
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
                aria-busy={mutation.isPending}
                className="mt-1 h-12 w-full rounded-xl bg-[#384CCA] font-semibold text-white shadow-[0_8px_20px_-10px_rgba(56,76,202,0.8)] hover:bg-[#2E3FAE] focus-visible:ring-[#384CCA]/30"
              >
                Cập nhật mật khẩu
              </LoadingButton>
            </form>
          </Form>

          <div className="mt-7 flex items-start gap-3 border-t border-slate-100 pt-5 text-xs leading-5 text-slate-500">
            <LockKeyhole
              aria-hidden="true"
              className="mt-0.5 size-4 shrink-0 text-slate-400"
            />
            <p>
              Liên kết chỉ dùng được một lần. Nếu liên kết đã hết hạn, hãy yêu
              cầu một email khôi phục mới.
            </p>
          </div>
        </section>
      )}
    </ResetPasswordLayout>
  )
}

function getPasswordStrength(value: string) {
  const checks = [
    value.length >= 8,
    /[a-z]/.test(value) && /[A-Z]/.test(value),
    /\d/.test(value),
    /[^a-zA-Z0-9]/.test(value),
  ]
  const score = checks.filter(Boolean).length
  const label = ["Chưa có", "Yếu", "Trung bình", "Tốt", "Mạnh"][score]
  const color = [
    "bg-slate-200",
    "bg-rose-500",
    "bg-amber-500",
    "bg-lime-600",
    "bg-emerald-600",
  ][score]
  return { score, label, color }
}

function PasswordStrength({
  strength,
  visible,
}: {
  strength: ReturnType<typeof getPasswordStrength>
  visible: boolean
}) {
  if (!visible) return null
  return (
    <div className="space-y-2" data-testid="password-strength">
      <div
        role="progressbar"
        aria-label="Độ mạnh mật khẩu"
        aria-valuemin={0}
        aria-valuemax={4}
        aria-valuenow={strength.score}
        className="flex gap-1.5"
      >
        {Array.from({ length: 4 }, (_, index) => (
          <span
            key={index}
            aria-hidden="true"
            className={cn(
              "h-1.5 flex-1 rounded-full",
              index < strength.score ? strength.color : "bg-slate-200",
            )}
          />
        ))}
      </div>
      <p className="text-xs text-slate-600" aria-live="polite">
        Độ mạnh mật khẩu:{" "}
        <span className="font-semibold text-slate-800">{strength.label}</span>
      </p>
    </div>
  )
}

function ResetPasswordInput({
  className,
  ...props
}: Omit<React.ComponentProps<"input">, "type">) {
  const [visible, setVisible] = useState(false)
  return (
    <div className="relative">
      <input
        {...props}
        type={visible ? "text" : "password"}
        data-slot="input"
        className={cn(
          "h-12 w-full rounded-xl border border-slate-200 bg-white px-4 pr-12 text-base text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus-visible:border-[#384CCA] focus-visible:ring-[3px] focus-visible:ring-[#384CCA]/15 disabled:cursor-not-allowed disabled:opacity-60 sm:text-sm aria-invalid:border-red-500 aria-invalid:ring-2 aria-invalid:ring-red-500/15",
          className,
        )}
      />
      <button
        type="button"
        className="absolute inset-y-0 right-1 inline-flex w-10 items-center justify-center rounded-lg text-slate-500 outline-none hover:bg-slate-50 hover:text-slate-900 focus-visible:ring-2 focus-visible:ring-[#384CCA] disabled:pointer-events-none disabled:opacity-50"
        onClick={() => setVisible((current) => !current)}
        aria-label={visible ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
        aria-pressed={visible}
        disabled={props.disabled}
      >
        {visible ? (
          <EyeOff aria-hidden="true" className="size-4" />
        ) : (
          <Eye aria-hidden="true" className="size-4" />
        )}
      </button>
    </div>
  )
}

function getResetErrorMessage(error: Error): string {
  if (error instanceof AxiosError) {
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
    <main className="relative flex min-h-svh items-center justify-center overflow-x-hidden bg-[#f4f6fb] px-4 py-8 sm:px-6 sm:py-12">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -left-32 -top-36 size-96 rounded-full bg-[#384CCA]/10 blur-3xl"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -bottom-40 -right-32 size-[28rem] rounded-full bg-[#008689]/10 blur-3xl"
      />
      <div className="relative my-auto w-full max-w-[480px] overflow-hidden rounded-[28px] border border-white/80 bg-white shadow-[0_28px_90px_-38px_rgba(23,37,84,0.38)]">
        <header className="flex items-center gap-3 border-b border-slate-100 px-6 py-5 sm:px-10">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-[#384CCA] text-white shadow-sm">
            <Landmark aria-hidden="true" className="size-5" />
          </span>
          <div>
            <p className="text-sm font-bold tracking-wide text-slate-900">
              Smart Heritage
            </p>
            <p className="text-xs text-slate-500">
              Kết nối với di sản Việt Nam
            </p>
          </div>
          <span className="ml-auto hidden items-center gap-1.5 rounded-full bg-slate-50 px-3 py-1.5 text-[11px] font-medium text-slate-600 sm:inline-flex">
            <ShieldCheck
              aria-hidden="true"
              className="size-3.5 text-[#384CCA]"
            />{" "}
            Bảo mật tài khoản
          </span>
        </header>
        {children}
      </div>
    </main>
  )
}

function InvalidResetLink({ expired = true }: { expired?: boolean }) {
  return (
    <section
      className="px-6 py-10 text-center sm:px-10 sm:py-12"
      aria-labelledby="invalid-link-title"
    >
      <span className="mx-auto mb-5 flex size-16 items-center justify-center rounded-2xl bg-amber-50 text-amber-700">
        <CircleAlert aria-hidden="true" className="size-8" />
      </span>
      <p className="mb-2 text-xs font-bold uppercase tracking-[0.16em] text-amber-700">
        Cần liên kết mới
      </p>
      <h1
        id="invalid-link-title"
        className="text-2xl font-bold tracking-tight text-slate-950"
      >
        {expired ? "Liên kết đã hết hạn" : "Không tìm thấy mã xác thực"}
      </h1>
      <p className="mx-auto mt-3 max-w-sm text-sm leading-6 text-slate-600">
        {expired
          ? "Liên kết đặt lại mật khẩu không còn hiệu lực hoặc đã được sử dụng. Hãy yêu cầu một email khôi phục mới."
          : "Hãy mở lại liên kết trong email khôi phục hoặc yêu cầu gửi một email mới."}
      </p>
      <a
        href="/recover-password"
        className="mt-7 inline-flex h-12 w-full items-center justify-center rounded-xl bg-[#384CCA] px-6 text-sm font-semibold text-white shadow-sm transition hover:bg-[#2E3FAE] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#384CCA]/25 sm:w-auto"
      >
        Yêu cầu email khôi phục mới
      </a>
      <p className="mt-5 text-xs text-slate-500">
        Vì lý do bảo mật, liên kết chỉ có thể sử dụng một lần.
      </p>
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
    <section
      className="px-6 py-10 text-center sm:px-10 sm:py-12"
      aria-labelledby="reset-success-title"
    >
      <span className="mx-auto mb-5 flex size-[72px] items-center justify-center rounded-full bg-emerald-50 text-emerald-700 ring-8 ring-emerald-50/60">
        <CheckCircle2 aria-hidden="true" className="size-10" />
      </span>
      <p className="mb-2 text-sm font-semibold uppercase tracking-[0.14em] text-emerald-700">
        Hoàn tất bảo mật
      </p>
      <h1
        id="reset-success-title"
        className="text-2xl font-bold tracking-tight text-slate-950 sm:text-[28px]"
      >
        Mật khẩu đã được cập nhật
      </h1>
      <p className="mx-auto mt-2 max-w-sm text-sm leading-6 text-slate-600">
        Bạn có thể quay lại ứng dụng Smart Heritage Mobile và đăng nhập bằng mật
        khẩu mới.
      </p>

      {showReturnInstructions && (
        <div
          role="status"
          className="mt-6 rounded-xl border border-blue-100 bg-blue-50 p-4 text-left text-sm leading-6 text-[#1E2A5A]"
        >
          <p className="font-semibold">Mở lại Smart Heritage Mobile</p>
          <p className="mt-1">
            Trên điện thoại, hãy mở ứng dụng Smart Heritage từ màn hình chính
            rồi đăng nhập bằng mật khẩu mới.
          </p>
        </div>
      )}

      <Button
        type="button"
        onClick={onReturnClick}
        className="mt-7 h-12 w-full rounded-xl bg-[#384CCA] font-semibold text-white hover:bg-[#2E3FAE] focus-visible:ring-[#384CCA]/30"
      >
        {showReturnInstructions ? (
          <Check aria-hidden="true" className="size-4" />
        ) : (
          <Smartphone aria-hidden="true" className="size-4" />
        )}
        {showReturnInstructions ? "Đã hiểu" : "Quay lại ứng dụng Mobile"}
      </Button>
    </section>
  )
}
