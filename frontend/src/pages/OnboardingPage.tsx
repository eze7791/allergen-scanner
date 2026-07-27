import { useState } from "react"
import { createRestaurant, joinRestaurant, adminLogin, setSession } from "@/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { cn } from "@/lib/utils"
import { toast } from "sonner"
import { Loader2 } from "lucide-react"

type Mode = "create" | "join" | "admin"

const MODES: { value: Mode; label: string }[] = [
  { value: "create", label: "Create Restaurant" },
  { value: "join", label: "Join as Staff" },
  { value: "admin", label: "Admin Login" },
]

export default function OnboardingPage() {
  const [mode, setMode] = useState<Mode>("create")
  const [name, setName] = useState("")
  const [pin, setPin] = useState("")
  const [joinCode, setJoinCode] = useState("")
  const [loading, setLoading] = useState(false)

  const submit = async () => {
    setLoading(true)
    try {
      if (mode === "create") {
        if (!name.trim() || !pin.trim()) return
        setSession(await createRestaurant(name.trim(), pin.trim()))
      } else if (mode === "join") {
        if (!joinCode.trim()) return
        setSession(await joinRestaurant(joinCode.trim()))
      } else {
        if (!joinCode.trim() || !pin.trim()) return
        setSession(await adminLogin(joinCode.trim(), pin.trim()))
      }
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setLoading(false)
    }
  }

  const canSubmit =
    mode === "create" ? name.trim() && pin.trim() : mode === "join" ? joinCode.trim() : joinCode.trim() && pin.trim()

  return (
    <div className="flex min-h-dvh items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center space-y-1">
          <h1 className="text-xl font-semibold tracking-tight">Allergen Scanner</h1>
          <p className="text-sm text-muted-foreground">
            Search dishes, manage products, and keep every allergen documented for your team.
          </p>
        </div>

        <div className="flex rounded-lg border p-1 bg-muted/40">
          {MODES.map((m) => (
            <button
              key={m.value}
              onClick={() => setMode(m.value)}
              className={cn(
                "flex-1 rounded-md px-2 py-1.5 text-xs font-medium transition-colors cursor-pointer",
                mode === m.value ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"
              )}
            >
              {m.label}
            </button>
          ))}
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">{MODES.find((m) => m.value === mode)?.label}</CardTitle>
            <CardDescription>
              {mode === "create" && "Set up a new restaurant and its admin PIN."}
              {mode === "join" && "Enter the join code your admin shared with you."}
              {mode === "admin" && "Sign back in as the restaurant admin."}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {mode === "create" && (
              <div className="space-y-2">
                <Label htmlFor="rname">Restaurant name</Label>
                <Input id="rname" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. BrewDog" />
              </div>
            )}
            {(mode === "join" || mode === "admin") && (
              <div className="space-y-2">
                <Label htmlFor="joincode">Join code</Label>
                <Input
                  id="joincode"
                  value={joinCode}
                  onChange={(e) => setJoinCode(e.target.value)}
                  placeholder="REST-1234"
                />
              </div>
            )}
            {(mode === "create" || mode === "admin") && (
              <div className="space-y-2">
                <Label htmlFor="pin">Admin PIN</Label>
                <Input id="pin" type="password" value={pin} onChange={(e) => setPin(e.target.value)} />
              </div>
            )}
            <Button onClick={submit} disabled={!canSubmit || loading} className="w-full gap-2">
              {loading && <Loader2 className="h-4 w-4 animate-spin" />}
              {loading ? "Please wait..." : "Continue"}
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
