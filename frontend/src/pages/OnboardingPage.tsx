import { useState } from "react"
import { createRestaurant, joinRestaurant, adminLogin, setSession } from "@/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { cn } from "@/lib/utils"
import { toast } from "sonner"
import { Loader2, ShieldCheck, UtensilsCrossed, KeyRound, Store } from "lucide-react"

type Mode = "create" | "join" | "admin"

const MODES: { value: Mode; label: string; icon: typeof Store }[] = [
  { value: "create", label: "New restaurant", icon: Store },
  { value: "join", label: "Join as staff", icon: KeyRound },
  { value: "admin", label: "Admin login", icon: ShieldCheck },
]

export default function OnboardingPage() {
  const [mode, setMode] = useState<Mode>("create")
  const [name, setName] = useState("")
  const [username, setUsername] = useState("")
  const [password, setPassword] = useState("")
  const [joinCode, setJoinCode] = useState("")
  const [loading, setLoading] = useState(false)

  const submit = async () => {
    setLoading(true)
    try {
      if (mode === "create") {
        if (!name.trim() || !username.trim() || !password.trim()) return
        setSession(await createRestaurant(name.trim(), username.trim(), password.trim()))
      } else if (mode === "join") {
        if (!joinCode.trim()) return
        setSession(await joinRestaurant(joinCode.trim()))
      } else {
        if (!username.trim() || !password.trim()) return
        setSession(await adminLogin(username.trim(), password.trim()))
      }
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setLoading(false)
    }
  }

  const canSubmit =
    mode === "create"
      ? name.trim() && username.trim() && password.trim()
      : mode === "join"
        ? joinCode.trim()
        : username.trim() && password.trim()

  return (
    <div className="relative flex min-h-dvh items-center justify-center overflow-hidden px-4 py-10">
      <div className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_80%_60%_at_50%_-10%,rgba(20,184,166,0.18),transparent)]" />
      <div className="pointer-events-none absolute -top-32 -left-24 -z-10 h-72 w-72 rounded-full bg-teal-500/10 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-32 -right-24 -z-10 h-72 w-72 rounded-full bg-emerald-500/10 blur-3xl" />

      <div className="w-full max-w-sm space-y-8">
        <div className="text-center space-y-3">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-teal-500/25">
            <UtensilsCrossed className="h-7 w-7 text-white" />
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Allergen Scanner</h1>
            <p className="mt-1.5 text-sm text-muted-foreground text-balance">
              Instantly check every dish for allergens — built for the floor, trusted by the kitchen.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-2">
          {MODES.map((m) => (
            <button
              key={m.value}
              onClick={() => setMode(m.value)}
              className={cn(
                "flex flex-col items-center gap-1.5 rounded-xl border px-2 py-3 text-xs font-medium transition-all cursor-pointer",
                mode === m.value
                  ? "border-teal-500/40 bg-teal-500/10 text-teal-700 dark:text-teal-400 shadow-sm"
                  : "border-border/60 text-muted-foreground hover:border-border hover:bg-muted/40"
              )}
            >
              <m.icon className="h-4 w-4" />
              {m.label}
            </button>
          ))}
        </div>

        <div className="rounded-2xl border bg-card/60 backdrop-blur-sm shadow-xl shadow-black/5 p-6 space-y-5">
          <div className="space-y-1">
            <h2 className="text-base font-semibold">{MODES.find((m) => m.value === mode)?.label}</h2>
            <p className="text-xs text-muted-foreground">
              {mode === "create" && "Set up a new restaurant with your own admin username and password."}
              {mode === "join" && "Enter the join code your admin shared with you."}
              {mode === "admin" && "Sign in with your personal admin username and password."}
            </p>
          </div>

          <div className="space-y-4">
            {mode === "create" && (
              <div className="space-y-1.5">
                <Label htmlFor="rname">Restaurant name</Label>
                <Input id="rname" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. BrewDog" className="h-11" />
              </div>
            )}
            {mode === "join" && (
              <div className="space-y-1.5">
                <Label htmlFor="joincode">Join code</Label>
                <Input
                  id="joincode"
                  value={joinCode}
                  onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
                  placeholder="ask your admin"
                  autoCapitalize="characters"
                  className="h-11 tracking-widest uppercase font-mono text-center"
                />
              </div>
            )}
            {(mode === "create" || mode === "admin") && (
              <div className="space-y-1.5">
                <Label htmlFor="username">Admin username</Label>
                <Input
                  id="username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="e.g. jane"
                  autoCapitalize="none"
                  className="h-11"
                />
              </div>
            )}
            {(mode === "create" || mode === "admin") && (
              <div className="space-y-1.5">
                <Label htmlFor="password">Admin password</Label>
                <Input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} className="h-11" />
              </div>
            )}
            <Button
              onClick={submit}
              disabled={!canSubmit || loading}
              className="w-full h-11 gap-2 bg-gradient-to-r from-teal-500 to-emerald-600 hover:from-teal-600 hover:to-emerald-700 text-white shadow-md shadow-teal-500/20"
            >
              {loading && <Loader2 className="h-4 w-4 animate-spin" />}
              {loading ? "Please wait..." : "Continue"}
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}
