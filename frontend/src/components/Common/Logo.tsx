import { Link } from "@tanstack/react-router"
import { Landmark } from "lucide-react"

import { cn } from "@/lib/utils"

interface LogoProps {
  variant?: "full" | "icon" | "responsive"
  className?: string
  asLink?: boolean
}

export function Logo({
  variant = "full",
  className,
  asLink = true,
}: LogoProps) {
  const content =
    variant === "responsive" ? (
      <div className={cn("flex min-w-0 items-center gap-2.5", className)}>
        <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary text-primary-foreground shadow-sm">
          <Landmark className="size-[18px]" />
        </span>
        <span className="min-w-0 group-data-[collapsible=icon]:hidden">
          <span className="block truncate text-[13px] font-bold tracking-wide text-sidebar-foreground">Smart Heritage</span>
          <span className="block text-[10px] leading-4 text-sidebar-foreground/60">Admin Console</span>
        </span>
      </div>
    ) : (
      <div className={cn("flex items-center gap-3", className)}>
        <span className="flex size-12 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-lg">
          <Landmark className="size-6" />
        </span>
        <span className="text-xl font-bold tracking-wide text-white">Smart Heritage</span>
      </div>
    )

  if (!asLink) return content
  return <Link to="/">{content}</Link>
}
