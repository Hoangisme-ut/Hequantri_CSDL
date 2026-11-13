import { zodResolver } from "@hookform/resolvers/zod"
import { useMutation } from "@tanstack/react-query"
import { createFileRoute, Link as RouterLink } from "@tanstack/react-router"
import { AxiosError } from "axios"
import {
  CheckCircle2,
  CircleAlert,
  Eye,
  EyeOff,
  LockKeyhole,
  ShieldCheck,
} from "lucide-react"
import { useMemo, useState } from "react"
import { useForm } from "react-hook-form"
import { z } from "zod"

import { LoginService } from "@/client"
import { AuthLayout } from "@/components/Common/AuthLayout"
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
      .min(1, { message: "Please enter a new password." })
      .min(8, { message: "Password must be at least 8 characters." }),
    confirm_password: z
      .string()
      .min(1, { message: "Please confirm your new password." }),
  })
  .refine((data) => data.new_password === data.confirm_password, {
    message: "Passwords do not match.",
    path: ["confirm_password"],
  })

type FormData = z.infer<typeof formSchema>

export const Route = createFileRoute("/reset-password")({
  component: ResetPassword,
  validateSearch: searchSchema,
  head: () => ({
    meta: [{ title: "Reset Password | Smart Heritage Admin" }],
  }),
})

function ResetPassword() {
  const { token } = Route.useSearch()
  const [isComplete, setIsComplete] = useState(false)
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
    <AuthLayout>
      {isComplete ? (
        <ResetSuccess />
      ) : invalidToken ? (
        <InvalidResetLink expired />
      ) : !token ? (
        <InvalidResetLink expired={false} />
      ) : (
        <div className="flex flex-col gap-6">
          <div className="flex flex-col items-center gap-2 text-center">
            <h1 className="text-2xl font-bold" id="reset-title">
              Reset password
            </h1>
            <p className="text-sm text-muted-foreground">
              Create a new password for your administrator account.
            </p>
          </div>

          {submitError && (
            <Alert
              variant="destructive"
              className="border-red-200 bg-red-50 text-red-800"
            >
              <CircleAlert aria-hidden="true" />
              <AlertTitle>Unable to update password</AlertTitle>
              <AlertDescription className="text-red-800">
                {submitError}
              </AlertDescription>
            </Alert>
          )}

          <Form {...form}>
            <form
              onSubmit={form.handleSubmit(onSubmit)}
              className="flex flex-col gap-4"
              noValidate
            >
              <FormField
                control={form.control}
                name="new_password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>New password</FormLabel>
                    <FormControl>
                      <ResetPasswordInput
                        data-testid="new-password-input"
                        autoComplete="new-password"
                        placeholder="Enter new password"
                        disabled={mutation.isPending}
                        {...field}
                      />
                    </FormControl>
                    <p className="text-xs text-muted-foreground">
                      Minimum 8 characters.
                    </p>
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
                    <FormLabel>Confirm new password</FormLabel>
                    <FormControl>
                      <ResetPasswordInput
                        data-testid="confirm-password-input"
                        autoComplete="new-password"
                        placeholder="Re-enter new password"
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
                className="mt-1 w-full"
              >
                Update password
              </LoadingButton>
            </form>
          </Form>

          <div className="flex items-start gap-2 text-xs text-muted-foreground">
            <LockKeyhole
              aria-hidden="true"
              className="mt-0.5 size-4 shrink-0"
            />
            <p>
              This link can only be used once. If the link has expired, request
              a new password recovery email.
            </p>
          </div>
        </div>
      )}
    </AuthLayout>
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
  const label = ["None", "Weak", "Fair", "Good", "Strong"][score]
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
        aria-label="Password strength"
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
      <p className="text-xs text-muted-foreground" aria-live="polite">
        Password strength:{" "}
        <span className="font-semibold text-foreground">{strength.label}</span>
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
          "h-10 w-full rounded-md border border-input bg-background px-3 pr-10 text-base shadow-sm outline-none transition placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/20 disabled:cursor-not-allowed disabled:opacity-60 sm:text-sm aria-invalid:border-destructive aria-invalid:ring-2 aria-invalid:ring-destructive/20",
          className,
        )}
      />
      <button
        type="button"
        className="absolute inset-y-0 right-1 inline-flex w-9 items-center justify-center rounded-md text-muted-foreground outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50"
        onClick={() => setVisible((current) => !current)}
        aria-label={visible ? "Hide password" : "Show password"}
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
      return "Password does not meet requirements. Please check and try again."
    }
    if (!error.response) {
      return "Unable to connect to the server. Please check your connection and try again."
    }
  }
  return "An error occurred while updating your password. Please try again."
}

function InvalidResetLink({ expired = true }: { expired?: boolean }) {
  return (
    <div className="flex flex-col items-center gap-4 text-center">
      <span className="flex size-16 items-center justify-center rounded-full bg-amber-50 text-amber-700 ring-8 ring-amber-50/60">
        <CircleAlert aria-hidden="true" className="size-8" />
      </span>
      <div>
        <p className="mb-1 text-xs font-bold uppercase tracking-widest text-amber-700">
          New link required
        </p>
        <h1
          id="invalid-link-title"
          className="text-2xl font-bold tracking-tight"
        >
          {expired ? "Link expired" : "No reset token found"}
        </h1>
        <p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">
          {expired
            ? "This password reset link is no longer valid or has already been used. Please request a new recovery email."
            : "Please open the link from your recovery email or request a new one."}
        </p>
      </div>
      <a
        href="/recover-password"
        className="inline-flex h-10 items-center justify-center rounded-md bg-primary px-6 text-sm font-semibold text-primary-foreground shadow-sm transition hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25"
      >
        Request a new recovery email
      </a>
      <p className="text-xs text-muted-foreground">
        For security, links can only be used once.
      </p>
    </div>
  )
}

function ResetSuccess() {
  return (
    <div
      className="flex flex-col items-center gap-4 text-center"
      aria-labelledby="reset-success-title"
    >
      <span className="flex size-16 items-center justify-center rounded-full bg-emerald-50 text-emerald-700 ring-8 ring-emerald-50/60">
        <CheckCircle2 aria-hidden="true" className="size-9" />
      </span>
      <div>
        <p className="mb-1 text-xs font-bold uppercase tracking-widest text-emerald-700">
          Success
        </p>
        <h1
          id="reset-success-title"
          className="text-2xl font-bold tracking-tight"
        >
          Password updated
        </h1>
        <p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">
          Your password has been updated successfully. Sign in to continue.
        </p>
      </div>
      <Button asChild className="w-full">
        <RouterLink to="/login">
          <ShieldCheck aria-hidden="true" className="size-4" />
          Back to Sign In
        </RouterLink>
      </Button>
    </div>
  )
}
