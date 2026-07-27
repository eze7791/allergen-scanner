import { useState } from "react"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Search, X } from "lucide-react"
import type { Allergen } from "@/api"

export function AllergenBadges({
  allergens,
  variant,
}: {
  allergens: { id: number; name: string; note?: string }[]
  variant: "contains" | "may"
}) {
  if (allergens.length === 0) return null
  return (
    <div className="flex flex-wrap gap-1">
      {allergens.map((a) => (
        <Badge
          key={a.id}
          variant={variant === "contains" ? "default" : "outline"}
          className={variant === "may" ? "text-[10px] px-1.5 py-0 text-amber-600 border-amber-300" : "text-[10px] px-1.5 py-0"}
          title={a.note ? `Source: ${a.note}` : undefined}
        >
          {a.name}
          {a.note && <span className="ml-1 opacity-70">({a.note})</span>}
        </Badge>
      ))}
    </div>
  )
}

export function AllergenPicker({
  allergens,
  selectedIds,
  onToggle,
}: {
  allergens: Allergen[]
  selectedIds: Set<number>
  onToggle: (id: number) => void
}) {
  const [searchQ, setSearchQ] = useState("")
  const available = allergens.filter((a) => !selectedIds.has(a.id))
  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-1.5">
        {Array.from(selectedIds).map((id) => {
          const a = allergens.find((x) => x.id === id)
          if (!a) return null
          return (
            <Badge key={id} variant="secondary" className="gap-1 pl-2 pr-1.5">
              {a.name}
              <button onClick={() => onToggle(id)} className="hover:text-destructive cursor-pointer">
                <X className="h-3 w-3" />
              </button>
            </Badge>
          )
        })}
        {selectedIds.size === 0 && <span className="text-xs text-muted-foreground italic">None selected</span>}
      </div>
      <div className="relative">
        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
        <Input
          placeholder="Search allergens..."
          className="pl-8 h-9 text-sm"
          value={searchQ}
          onChange={(e) => setSearchQ(e.target.value)}
        />
        {searchQ.trim() && (
          <div className="absolute left-0 right-0 top-full mt-1 z-50 max-h-48 overflow-y-auto rounded-lg border bg-popover p-1 shadow-md">
            {available.filter((a) => a.name.toLowerCase().includes(searchQ.toLowerCase())).length === 0 ? (
              <div className="px-2 py-1.5 text-xs text-muted-foreground">No matches</div>
            ) : (
              available
                .filter((a) => a.name.toLowerCase().includes(searchQ.toLowerCase()))
                .map((a) => (
                  <button
                    key={a.id}
                    className="w-full rounded-md px-2 py-1.5 text-left text-sm hover:bg-accent cursor-pointer"
                    onClick={() => {
                      onToggle(a.id)
                      setSearchQ("")
                    }}
                  >
                    {a.name}
                  </button>
                ))
            )}
          </div>
        )}
      </div>
    </div>
  )
}
