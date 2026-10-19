interface AuthLayoutProps {
  children: React.ReactNode
}

export function AuthLayout({ children }: AuthLayoutProps) {
  return (
    <div className="min-h-svh bg-background text-foreground lg:grid lg:grid-cols-[43%_57%]">
      <aside
        aria-label="Smart Heritage introduction"
        className="relative hidden min-h-svh overflow-hidden bg-[#132c47] bg-left bg-no-repeat lg:block"
        style={{
          backgroundImage: "url('/assets/images/smart-heritage-login-reference.png')",
          backgroundSize: "auto 100%",
        }}
      />
      <main className="flex min-h-svh flex-col items-center justify-center px-5 py-10 sm:px-8 lg:px-10">
        <div className="w-full max-w-[460px] rounded-2xl border border-border/70 bg-card shadow-2xl shadow-black/15">
          {children}
        </div>
        <p className="mt-6 max-w-[460px] text-center text-xs leading-5 text-muted-foreground">
          Restricted to authorised Smart Heritage administrators.
        </p>
      </main>
    </div>
  )
}
