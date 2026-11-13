import { zodResolver } from "@hookform/resolvers/zod"
import { useMutation } from "@tanstack/react-query"
import {
  createFileRoute,
  Link as RouterLink,
  redirect,
} from "@tanstack/react-router"
import { CheckCircle2, Mail } from "lucide-react"
import { useState } from "react"
import { useForm } from "react-hook-form"
import { z } from "zod"

import { LoginService } from "@/client"
import { AuthLayout } from "@/components/Common/AuthLayout"
import { Button } from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { LoadingButton } from "@/components/ui/loading-button"
import { isLoggedIn } from "@/hooks/useAuth"

const formSchema = z.object({
  email: z.email({ message: "Invalid email address" }),
})

type FormData = z.infer<typeof formSchema>

export const Route = createFileRoute("/recover-password")({
  component: RecoverPassword,
  beforeLoad: async () => {
    if (isLoggedIn()) {
      throw redirect({
        to: "/",
      })
    }
  },
  head: () => ({
    meta: [
      {
        title: "Recover Password - Smart Heritage Admin",
      },
    ],
  }),
})

function RecoverPassword() {
  const [submitted, setSubmitted] = useState(false)

  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      email: "",
    },
  })

  const recoverPassword = async (data: FormData) => {
    await LoginService.recoverPassword({
      path: { email: data.email },
    })
  }

  const mutation = useMutation({
    mutationFn: recoverPassword,
    onSuccess: () => {
      setSubmitted(true)
    },
    onError: () => {
      // Always show success to prevent email enumeration
      setSubmitted(true)
    },
  })

  const onSubmit = async (data: FormData) => {
    if (mutation.isPending) return
    mutation.mutate(data)
  }

  if (submitted) {
    return (
      <AuthLayout>
        <div
          className="flex flex-col items-center gap-4 text-center"
          role="status"
          aria-live="polite"
          data-testid="recovery-sent"
        >
          <span className="flex size-16 items-center justify-center rounded-full bg-emerald-50 text-emerald-700 ring-8 ring-emerald-50/60">
            <CheckCircle2 aria-hidden="true" className="size-9" />
          </span>
          <div>
            <p className="mb-1 text-xs font-bold uppercase tracking-widest text-emerald-700">
              Email sent
            </p>
            <h1 className="text-2xl font-bold tracking-tight">
              Check your inbox
            </h1>
            <p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">
              If that email is registered, you will receive a password recovery
              link shortly. Please check your inbox.
            </p>
          </div>
          <Button asChild variant="outline" className="w-full">
            <RouterLink to="/login">Back to Sign In</RouterLink>
          </Button>
        </div>
      </AuthLayout>
    )
  }

  return (
    <AuthLayout>
      <Form {...form}>
        <form
          onSubmit={form.handleSubmit(onSubmit)}
          className="flex flex-col gap-6"
        >
          <div className="flex flex-col items-center gap-2 text-center">
            <span className="mb-1 flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground">
              <Mail aria-hidden="true" className="size-6" />
            </span>
            <h1 className="text-2xl font-bold">Password Recovery</h1>
            <p className="text-sm text-muted-foreground">
              Enter your administrator email to receive a reset link.
            </p>
          </div>

          <div className="grid gap-4">
            <FormField
              control={form.control}
              name="email"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Email</FormLabel>
                  <FormControl>
                    <Input
                      data-testid="email-input"
                      placeholder="admin@example.com"
                      type="email"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <LoadingButton
              type="submit"
              className="w-full"
              loading={mutation.isPending}
            >
              Continue
            </LoadingButton>
          </div>

          <div className="text-center text-sm">
            Remember your password?{" "}
            <RouterLink to="/login" className="underline underline-offset-4">
              Log in
            </RouterLink>
          </div>
        </form>
      </Form>
    </AuthLayout>
  )
}
