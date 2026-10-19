import { createFileRoute } from "@tanstack/react-router"
import { LockKeyhole, ShieldCheck, UserRound } from "lucide-react"
import { useState } from "react"

import ChangePassword from "@/components/UserSettings/ChangePassword"
import DeleteAccount from "@/components/UserSettings/DeleteAccount"
import UserInformation from "@/components/UserSettings/UserInformation"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { useTheme } from "@/components/theme-provider"
import useAuth from "@/hooks/useAuth"
import { getInitials } from "@/utils"

export const Route = createFileRoute("/_layout/account")({
  component: Account,
  head: () => ({ meta: [{ title: "Account - Smart Heritage" }] }),
})

function Account() {
  const { user } = useAuth()
  const { resolvedTheme, setTheme } = useTheme()
  const [language, setLanguage] = useState("")
  const [timezone, setTimezone] = useState("")
  const [dateFormat, setDateFormat] = useState("")
  const [emailAlerts, setEmailAlerts] = useState(false)
  const [weeklyDigest, setWeeklyDigest] = useState(false)
  const initials = getInitials(user?.full_name || user?.email || "User")

  return (
    <div className="grid items-start gap-4 xl:grid-cols-[1.55fr_0.95fr]">
      <div className="flex flex-col gap-4">
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Profile</CardTitle><Badge variant="secondary">Account</Badge></CardHeader>
          <CardContent className="grid gap-4 p-5 sm:grid-cols-[auto_1fr]">
            <div className="flex size-14 items-center justify-center rounded-full bg-blue-600 text-lg font-bold text-white">{initials}</div>
            <div className="min-w-0">
              <div className="mb-3"><p className="truncate text-lg font-semibold">{user?.full_name || "Name not provided"}</p><Badge variant={user?.is_superuser ? "default" : "secondary"}>{user?.is_superuser ? "Administrator" : "User"}</Badge></div>
              <dl className="grid gap-2 text-sm sm:grid-cols-[120px_1fr]">
                <dt className="text-muted-foreground">Email</dt><dd className="break-all">{user?.email ?? "Loading account…"}</dd>
                <dt className="text-muted-foreground">Site access</dt><dd className="text-muted-foreground">Not provided by the current account API</dd>
                <dt className="text-muted-foreground">Organisation</dt><dd className="text-muted-foreground">Not provided by the current account API</dd>
              </dl>
            </div>
            <div className="sm:col-span-2"><UserInformation /></div>
          </CardContent>
        </Card>

        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Password &amp; security</CardTitle><ShieldCheck className="size-4 text-primary" /></CardHeader>
          <CardContent className="grid gap-5 p-5 lg:grid-cols-[1.2fr_0.8fr]">
            <ChangePassword />
            <div className="rounded-lg border border-border/70 bg-background/15 p-4">
              <div className="flex items-center gap-2 font-medium"><LockKeyhole className="size-4 text-primary" />Two-step verification</div>
              <p className="mt-2 text-sm text-muted-foreground">Two-step verification is not available in the current account API.</p>
              <Button className="mt-3" variant="outline" disabled>Set up verification</Button>
            </div>
          </CardContent>
        </Card>
        <DeleteAccount />
      </div>

      <div className="flex flex-col gap-4">
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Personal preferences</CardTitle></CardHeader>
          <CardContent className="grid gap-4 p-5">
            <Badge variant="secondary" className="w-fit">Local preview</Badge>
            <label className="grid gap-1.5 text-sm font-medium">Console language<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={language} onChange={(event) => setLanguage(event.target.value)}><option value="">Choose language</option><option value="en">English</option><option value="fr">French</option><option value="de">German</option></select></label>
            <label className="grid gap-1.5 text-sm font-medium">Time zone<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={timezone} onChange={(event) => setTimezone(event.target.value)}><option value="">Choose time zone</option><option value="utc">UTC</option><option value="local">Device time zone</option></select></label>
            <label className="grid gap-1.5 text-sm font-medium">Date format<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={dateFormat} onChange={(event) => setDateFormat(event.target.value)}><option value="">Choose date format</option><option value="dmy">DD MMM YYYY</option><option value="mdy">MMM DD, YYYY</option><option value="iso">YYYY-MM-DD</option></select></label>
            <div className="grid gap-2 text-sm"><p className="font-medium">Appearance</p><div className="flex gap-2"><Button variant={resolvedTheme === "light" ? "default" : "outline"} size="sm" onClick={() => setTheme("light")}>Light</Button><Button variant={resolvedTheme === "dark" ? "default" : "outline"} size="sm" onClick={() => setTheme("dark")}>Dark</Button></div></div>
            <label className="flex items-start justify-between gap-3 text-sm"><span><span className="block font-medium">Email notifications</span><span className="text-xs text-muted-foreground">Alert delivery preferences are not connected.</span></span><input type="checkbox" checked={emailAlerts} onChange={(event) => setEmailAlerts(event.target.checked)} aria-label="Email notifications" /></label>
            <label className="flex items-start justify-between gap-3 text-sm"><span><span className="block font-medium">Weekly report digest</span><span className="text-xs text-muted-foreground">Digest delivery preferences are not connected.</span></span><input type="checkbox" checked={weeklyDigest} onChange={(event) => setWeeklyDigest(event.target.checked)} aria-label="Weekly report digest" /></label>
            <Button disabled title="Personal preference persistence is not available">Save preferences</Button>
            <p className="text-xs text-muted-foreground">Language, time zone, date format and notification selections are local UI drafts only.</p>
          </CardContent>
        </Card>
        <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><UserRound className="size-4 text-primary" />Your access</CardTitle></CardHeader><CardContent className="p-5 text-sm text-muted-foreground">Your role is determined by the account API's administrator flag. Site-scoped access details are not available.</CardContent></Card>
      </div>
    </div>
  )
}
