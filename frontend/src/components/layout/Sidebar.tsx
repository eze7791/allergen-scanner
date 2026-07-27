import { type LucideIcon } from "lucide-react"
import { cn } from "@/lib/utils"
import { buttonVariants } from "@/components/ui/button"
import { Link, useLocation } from "react-router-dom"
import { LogOut, Scan, Search, Utensils } from "lucide-react"
import { clearSession, getSession } from "@/api"

const navItems: { label: string; to: string; icon: LucideIcon; adminOnly?: boolean }[] = [
  { label: "Search", to: "/", icon: Search },
  { label: "Recipes", to: "/recipes", icon: Utensils },
  { label: "Scan", to: "/scan", icon: Scan, adminOnly: true },
]

export default function Sidebar() {
  const { pathname } = useLocation()
  const session = getSession()
  const items = navItems.filter((item) => !item.adminOnly || session?.role === "admin")

  const isActive = (to: string) =>
    to === "/" ? pathname === "/" : pathname.startsWith(to)

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="hidden md:flex fixed inset-y-0 left-0 z-30 w-56 flex-col border-r border-sidebar-border bg-sidebar">
        <div className="flex h-14 items-center gap-2 border-b border-sidebar-border px-5">
          <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary text-xs font-bold text-primary-foreground">
            AS
          </div>
          <span className="text-sm font-semibold text-sidebar-foreground truncate">
            {session?.restaurantName ?? "Allergen Scan"}
          </span>
        </div>
        <nav className="flex-1 space-y-0.5 p-3">
          {items.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className={cn(
                buttonVariants({ variant: "ghost" }),
                "w-full justify-start gap-3 px-3 text-sm font-normal",
                isActive(item.to)
                  ? "bg-sidebar-accent text-sidebar-accent-foreground font-medium"
                  : "text-sidebar-foreground/70 hover:text-sidebar-foreground hover:bg-sidebar-accent/50"
              )}
            >
              <item.icon className="h-4 w-4 shrink-0" />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-sidebar-border p-3 space-y-2">
          <div className="rounded-lg bg-sidebar-accent/50 px-3 py-2">
            <p className="text-[11px] text-sidebar-foreground/60 leading-tight">
              Search a dish to see its allergens instantly
            </p>
          </div>
          <button
            onClick={clearSession}
            className={cn(
              buttonVariants({ variant: "ghost" }),
              "w-full justify-start gap-3 px-3 text-sm font-normal text-sidebar-foreground/70 hover:text-sidebar-foreground hover:bg-sidebar-accent/50"
            )}
          >
            <LogOut className="h-4 w-4 shrink-0" />
            Log out
          </button>
        </div>
      </aside>

      {/* Mobile bottom tab bar */}
      <nav className="md:hidden fixed inset-x-0 bottom-0 z-30 flex h-14 border-t border-sidebar-border bg-sidebar safe-area-bottom">
        {items.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            className={cn(
              "flex flex-1 flex-col items-center justify-center gap-0.5 text-[10px] font-medium transition-colors",
              isActive(item.to)
                ? "text-sidebar-accent-foreground"
                : "text-sidebar-foreground/50 hover:text-sidebar-foreground/80"
            )}
          >
            <item.icon className="h-5 w-5" />
            {item.label}
          </Link>
        ))}
      </nav>
    </>
  )
}
