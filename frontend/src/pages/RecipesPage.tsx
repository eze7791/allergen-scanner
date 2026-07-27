import { useState, useEffect } from "react"
import { getRecipes, createRecipe, deleteRecipe, getAllergens, getSession, type Allergen, type Recipe } from "@/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { AllergenBadges, AllergenPicker } from "@/components/AllergenPicker"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { toast } from "sonner"
import { Loader2, Plus, Trash2 } from "lucide-react"

export default function RecipesPage() {
  const [name, setName] = useState("")
  const [desc, setDesc] = useState("")
  const [category, setCategory] = useState("")
  const [allergens, setAllergens] = useState<Allergen[]>([])
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())
  const [mcSelectedIds, setMcSelectedIds] = useState<Set<number>>(new Set())
  const [recipes, setRecipes] = useState<Recipe[]>([])
  const [loading, setLoading] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<Recipe | null>(null)
  const isAdmin = getSession()?.role === "admin"

  useEffect(() => {
    getAllergens().then(setAllergens)
    loadRecipes()
  }, [])

  const loadRecipes = async () => {
    try {
      setRecipes(await getRecipes())
    } catch {
      setRecipes([])
    }
  }

  const toggle = (setter: typeof setSelectedIds) => (id: number) =>
    setter((prev) => {
      const s = new Set(prev)
      if (s.has(id)) s.delete(id)
      else s.add(id)
      return s
    })

  const create = async () => {
    if (!name.trim()) return
    setLoading(true)
    try {
      const r = await createRecipe({
        name: name.trim(),
        description: desc.trim() || undefined,
        category: category.trim() || undefined,
        allergen_ids: Array.from(selectedIds),
        may_contain_allergen_ids: Array.from(mcSelectedIds),
      })
      setRecipes((prev) => [r, ...prev])
      setName("")
      setDesc("")
      setCategory("")
      setSelectedIds(new Set())
      setMcSelectedIds(new Set())
      toast.success("Dish created!")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!deleteTarget) return
    try {
      await deleteRecipe(deleteTarget.id)
      setRecipes((prev) => prev.filter((r) => r.id !== deleteTarget.id))
      setDeleteTarget(null)
      toast.success("Dish deleted")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    }
  }

  const grouped = recipes.reduce<Record<string, Recipe[]>>((acc, r) => {
    const key = r.category || "Uncategorized"
    ;(acc[key] ??= []).push(r)
    return acc
  }, {})

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Dishes</h1>
        <p className="text-sm text-muted-foreground mt-1">Manage the menu and each dish's allergens</p>
      </div>

      {isAdmin && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Add Dish</CardTitle>
            <CardDescription>Tag a menu item with the allergens it contains or may contain</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Dish name</Label>
              <Input id="name" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Oklahoma Stack" />
            </div>

            <div className="space-y-2">
              <Label htmlFor="category">Category (optional)</Label>
              <Input id="category" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Burgers" />
            </div>

            <div className="space-y-2">
              <Label htmlFor="desc">Description (optional)</Label>
              <Textarea id="desc" value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} />
            </div>

            <div className="space-y-2">
              <Label>Contains</Label>
              <AllergenPicker allergens={allergens} selectedIds={selectedIds} onToggle={toggle(setSelectedIds)} />
            </div>

            <div className="space-y-2">
              <Label>May contain</Label>
              <AllergenPicker allergens={allergens} selectedIds={mcSelectedIds} onToggle={toggle(setMcSelectedIds)} />
            </div>
          </CardContent>
          <CardFooter>
            <Button onClick={create} disabled={!name.trim() || loading} className="w-full gap-2">
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
              {loading ? "Creating..." : "Add Dish"}
            </Button>
          </CardFooter>
        </Card>
      )}

      {recipes.length === 0 ? (
        <div className="py-12 text-center text-sm text-muted-foreground">No dishes yet. Add one above.</div>
      ) : (
        Object.entries(grouped).map(([cat, items]) => (
          <div key={cat} className="space-y-2">
            <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">{cat}</h2>
            {items.map((r) => (
              <Card key={r.id} className="group">
                <CardContent className="p-4">
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0 flex-1 space-y-1.5">
                      <h3 className="text-sm font-medium">{r.name}</h3>
                      {r.description && <p className="text-xs text-muted-foreground">{r.description}</p>}
                      <AllergenBadges allergens={r.allergens} variant="contains" />
                      <AllergenBadges allergens={r.may_contain_allergens} variant="may" />
                      {r.allergens.length === 0 && r.may_contain_allergens.length === 0 && (
                        <Badge variant="secondary" className="text-[10px] px-1.5 py-0">None</Badge>
                      )}
                    </div>
                    {isAdmin && (
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 shrink-0 text-muted-foreground opacity-100 hover:text-destructive md:opacity-0 md:group-hover:opacity-100 transition-opacity"
                        onClick={() => setDeleteTarget(r)}
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </Button>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        ))
      )}

      <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete dish?</DialogTitle>
            <DialogDescription>Are you sure you want to delete "{deleteTarget?.name}"?</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Cancel</Button>
            <Button variant="destructive" onClick={handleDelete}>Delete</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
