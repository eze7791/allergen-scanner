import { useState, useEffect, useRef } from "react"
import { suggest, getFoodItem, getRecipe, updateFoodItem, deleteFoodItem, getAllergens, getFoodItems, updateRecipe, deleteRecipe, type Allergen, type FoodItem, type Recipe } from "@/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet"
import { Separator } from "@/components/ui/separator"
import { toast } from "sonner"
import { Loader2, Search, Pencil, Trash2, X } from "lucide-react"

export default function SearchPage() {
  const [query, setQuery] = useState("")
  const [items, setItems] = useState<FoodItem[]>([])
  const [recipes, setRecipes] = useState<Recipe[]>([])
  const [loading, setLoading] = useState(false)
  const [searched, setSearched] = useState(false)
  const [allergens, setAllergens] = useState<Allergen[]>([])
  const [foodItems, setFoodItems] = useState<FoodItem[]>([])
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined)

  useEffect(() => {
    getAllergens().then(setAllergens)
    getFoodItems().then(setFoodItems)
  }, [])

  const doSearch = (q: string) => {
    setQuery(q)
    clearTimeout(debounceRef.current)
    if (!q.trim()) {
      setItems([])
      setRecipes([])
      setSearched(false)
      return
    }
    debounceRef.current = setTimeout(async () => {
      setLoading(true)
      setSearched(true)
      try {
        const data = await suggest(q)
        const [itemResults, recipeResults] = await Promise.all([
          Promise.all(data.items.map((i) => getFoodItem(i.id))),
          Promise.all(data.recipes.map((r) => getRecipe(r.id))),
        ])
        setItems(itemResults)
        setRecipes(recipeResults)
      } catch {
        toast.error("Search failed")
      } finally {
        setLoading(false)
      }
    }, 200)
  }

  const handleDeleteItem = async (id: number) => {
    try {
      await deleteFoodItem(id)
      setItems((prev) => prev.filter((i) => i.id !== id))
      toast.success("Item deleted")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    }
  }

  const handleDeleteRecipe = async (id: number) => {
    try {
      await deleteRecipe(id)
      setRecipes((prev) => prev.filter((r) => r.id !== id))
      toast.success("Recipe deleted")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Search</h1>
        <p className="text-sm text-muted-foreground mt-1">Find products and recipes</p>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input
          value={query}
          onChange={(e) => doSearch(e.target.value)}
          placeholder="Search products and recipes..."
          className="pl-9 h-11"
        />
      </div>

      {loading && (
        <div className="flex justify-center py-12">
          <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
        </div>
      )}

      {!loading && searched && items.length === 0 && recipes.length === 0 && (
        <div className="py-12 text-center text-sm text-muted-foreground">
          No results found for "{query}"
        </div>
      )}

      {items.length > 0 && (
        <section>
          <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-3">Products</h2>
          <div className="space-y-2">
            {items.map((item) => (
              <ItemCard
                key={item.id}
                item={item}
                allergens={allergens}
                onDelete={handleDeleteItem}
                onUpdate={(updated) =>
                  setItems((prev) => prev.map((i) => (i.id === updated.id ? updated : i)))
                }
              />
            ))}
          </div>
        </section>
      )}

      {recipes.length > 0 && (
        <section>
          <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-3">Recipes</h2>
          <div className="space-y-2">
            {recipes.map((recipe) => (
              <RecipeCard
                key={recipe.id}
                recipe={recipe}
                foodItems={foodItems}
                onDelete={handleDeleteRecipe}
                onUpdate={(updated) =>
                  setRecipes((prev) => prev.map((r) => (r.id === updated.id ? updated : r)))
                }
              />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}

function ItemCard({
  item,
  allergens,
  onDelete,
  onUpdate,
}: {
  item: FoodItem
  allergens: Allergen[]
  onDelete: (id: number) => void
  onUpdate: (item: FoodItem) => void
}) {
  const [open, setOpen] = useState(false)
  const [name, setName] = useState(item.name)
  const [desc, setDesc] = useState(item.description || "")
  const [cat, setCat] = useState(item.category || "")
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set(item.allergens.map((a) => a.id)))
  const [saving, setSaving] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [searchQ, setSearchQ] = useState("")

  useEffect(() => {
    if (open) {
      setName(item.name)
      setDesc(item.description || "")
      setCat(item.category || "")
      setSelectedIds(new Set(item.allergens.map((a) => a.id)))
    }
  }, [open, item])

  const save = async () => {
    if (!name.trim()) return
    setSaving(true)
    try {
      const updated = await updateFoodItem(item.id, {
        name: name.trim(),
        ...(desc ? { description: desc } : {}),
        ...(cat ? { category: cat } : {}),
        allergen_ids: Array.from(selectedIds),
      })
      onUpdate(updated)
      setOpen(false)
      toast.success("Item updated")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setSaving(false)
    }
  }

  const available = allergens.filter((a) => !selectedIds.has(a.id))

  return (
    <Card className="group">
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0 flex-1">
            <h3 className="text-sm font-medium">{item.name}</h3>
            <p className="text-xs text-muted-foreground mt-0.5">
              {item.category || "Uncategorized"}
              {item.description && ` · ${item.description}`}
            </p>
            <div className="flex flex-wrap gap-1 mt-2">
              {item.allergens.length === 0 ? (
                <Badge variant="secondary" className="text-[10px] px-1.5 py-0">None</Badge>
              ) : (
                item.allergens.map((a) => (
                  <Badge key={a.id} variant="outline" className="text-[10px] px-1.5 py-0">
                    {a.name}
                  </Badge>
                ))
              )}
            </div>
          </div>
          <div className="flex gap-1 shrink-0 opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity">
            <Sheet open={open} onOpenChange={setOpen}>
              <SheetTrigger render={<Button variant="ghost" size="icon" className="h-8 w-8" />}>
                <Pencil className="h-3.5 w-3.5" />
              </SheetTrigger>
              <SheetContent className="w-full sm:max-w-md">
                <SheetHeader>
                  <SheetTitle>Edit Product</SheetTitle>
                  <SheetDescription>Update product details and allergens</SheetDescription>
                </SheetHeader>
                <div className="flex-1 space-y-6 overflow-y-auto px-4">
                  <div className="space-y-2">
                    <Label htmlFor={`edit-name-${item.id}`}>Name</Label>
                    <Input id={`edit-name-${item.id}`} value={name} onChange={(e) => setName(e.target.value)} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor={`edit-desc-${item.id}`}>Description</Label>
                    <Textarea id={`edit-desc-${item.id}`} value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor={`edit-cat-${item.id}`}>Category</Label>
                    <Input id={`edit-cat-${item.id}`} value={cat} onChange={(e) => setCat(e.target.value)} />
                  </div>
                  <Separator />
                  <div className="space-y-2">
                    <Label>Allergens</Label>
                    <div className="flex flex-wrap gap-1.5">
                      {Array.from(selectedIds).map((id) => {
                        const a = allergens.find((x) => x.id === id)
                        if (!a) return null
                        return (
                          <Badge key={id} variant="secondary" className="gap-1 pl-2 pr-1.5">
                            {a.name}
                            <button onClick={() => setSelectedIds((prev) => { const s = new Set(prev); s.delete(id); return s })} className="hover:text-destructive cursor-pointer">
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
                                    setSelectedIds((prev) => new Set(prev).add(a.id))
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
                </div>
                <div className="border-t px-4 py-3 flex items-center justify-end gap-2">
                  <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
                  <Button onClick={save} disabled={saving || !name.trim()} className="gap-2">
                    {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                    {saving ? "Saving..." : "Save"}
                  </Button>
                </div>
              </SheetContent>
            </Sheet>

            <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
              <DialogTrigger render={<Button variant="ghost" size="icon" className="h-8 w-8 hover:text-destructive" />}>
                <Trash2 className="h-3.5 w-3.5" />
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Delete product?</DialogTitle>
                  <DialogDescription>
                    Are you sure you want to delete "{item.name}"? This action cannot be undone.
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setDeleteOpen(false)}>Cancel</Button>
                  <Button variant="destructive" onClick={() => { onDelete(item.id); setDeleteOpen(false) }}>Delete</Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function RecipeCard({
  recipe,
  foodItems,
  onDelete,
  onUpdate,
}: {
  recipe: Recipe
  foodItems: FoodItem[]
  onDelete: (id: number) => void
  onUpdate: (recipe: Recipe) => void
}) {
  const [open, setOpen] = useState(false)
  const [name, setName] = useState(recipe.name)
  const [desc, setDesc] = useState(recipe.description || "")
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set(recipe.items.map((i) => i.id)))
  const [saving, setSaving] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [searchQ, setSearchQ] = useState("")

  useEffect(() => {
    if (open) {
      setName(recipe.name)
      setDesc(recipe.description || "")
      setSelectedIds(new Set(recipe.items.map((i) => i.id)))
      setSearchQ("")
    }
  }, [open, recipe])

  const save = async () => {
    if (!name.trim()) return
    setSaving(true)
    try {
      const updated = await updateRecipe(recipe.id, {
        name: name.trim(),
        ...(desc ? { description: desc } : {}),
        food_item_ids: Array.from(selectedIds),
      })
      onUpdate(updated)
      setOpen(false)
      toast.success("Recipe updated")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setSaving(false)
    }
  }

  const available = foodItems.filter((i) => !selectedIds.has(i.id))

  return (
    <Card className="group border-l-4 border-l-emerald-500">
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0 flex-1">
            <h3 className="text-sm font-medium">
              {recipe.name}
              <Badge variant="outline" className="ml-2 text-[10px] text-emerald-600 border-emerald-200 bg-emerald-50">Recipe</Badge>
            </h3>
            {recipe.description && (
              <p className="text-xs text-muted-foreground mt-0.5">{recipe.description}</p>
            )}
            <p className="text-xs text-muted-foreground mt-1">
              <span className="font-medium">Ingredients:</span> {recipe.items.map((i) => i.name).join(", ")}
            </p>
            <div className="flex flex-wrap gap-1 mt-2">
              {recipe.allergens.length === 0 ? (
                <Badge variant="secondary" className="text-[10px] px-1.5 py-0">None</Badge>
              ) : (
                recipe.allergens.map((a) => (
                  <Badge key={a.name} variant="outline" className="text-[10px] px-1.5 py-0">
                    {a.name}
                    <span className="ml-0.5 text-[9px] text-muted-foreground">({a.count}x)</span>
                  </Badge>
                ))
              )}
            </div>
            {recipe.allergens.length > 0 && (
              <p className="text-[10px] text-muted-foreground/60 mt-1.5 leading-tight">
                To remove allergens, edit or delete the source product
              </p>
            )}
          </div>
          <div className="flex gap-1 shrink-0 opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity">
            <Sheet open={open} onOpenChange={setOpen}>
              <SheetTrigger render={<Button variant="ghost" size="icon" className="h-8 w-8" />}>
                <Pencil className="h-3.5 w-3.5" />
              </SheetTrigger>
              <SheetContent className="w-full sm:max-w-md">
                <SheetHeader>
                  <SheetTitle>Edit Recipe</SheetTitle>
                  <SheetDescription>Update recipe name, description, and ingredients</SheetDescription>
                </SheetHeader>
                <div className="flex-1 space-y-6 overflow-y-auto px-4">
                  <div className="space-y-2">
                    <Label htmlFor={`rname-${recipe.id}`}>Name</Label>
                    <Input id={`rname-${recipe.id}`} value={name} onChange={(e) => setName(e.target.value)} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor={`rdesc-${recipe.id}`}>Description</Label>
                    <Textarea id={`rdesc-${recipe.id}`} value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} />
                  </div>
                  <Separator />
                  <div className="space-y-2">
                    <Label>Ingredients</Label>
                    <div className="flex flex-wrap gap-1.5">
                      {Array.from(selectedIds).map((id) => {
                        const item = foodItems.find((i) => i.id === id)
                        if (!item) return null
                        return (
                          <Badge key={id} variant="secondary" className="gap-1 pl-2 pr-1.5">
                            {item.name}
                            <button onClick={() => setSelectedIds((prev) => { const s = new Set(prev); s.delete(id); return s })} className="hover:text-destructive cursor-pointer">
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
                        placeholder="Search ingredients..."
                        className="pl-8 h-9 text-sm"
                        value={searchQ}
                        onChange={(e) => setSearchQ(e.target.value)}
                      />
                      {searchQ.trim() && (
                        <div className="absolute left-0 right-0 top-full mt-1 z-50 max-h-48 overflow-y-auto rounded-lg border bg-popover p-1 shadow-md">
                          {available.filter((i) => i.name.toLowerCase().includes(searchQ.toLowerCase())).length === 0 ? (
                            <div className="px-2 py-1.5 text-xs text-muted-foreground">No matches</div>
                          ) : (
                            available
                              .filter((i) => i.name.toLowerCase().includes(searchQ.toLowerCase()))
                              .map((item) => (
                                <button
                                  key={item.id}
                                  className="w-full rounded-md px-2 py-1.5 text-left text-sm hover:bg-accent cursor-pointer"
                                  onClick={() => {
                                    setSelectedIds((prev) => new Set(prev).add(item.id))
                                    setSearchQ("")
                                  }}
                                >
                                  {item.name}
                                </button>
                              ))
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
                <div className="border-t px-4 py-3 flex items-center justify-end gap-2">
                  <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
                  <Button onClick={save} disabled={saving || !name.trim()} className="gap-2">
                    {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                    {saving ? "Saving..." : "Save"}
                  </Button>
                </div>
              </SheetContent>
            </Sheet>

            <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
              <DialogTrigger render={<Button variant="ghost" size="icon" className="h-8 w-8 hover:text-destructive" />}>
                <Trash2 className="h-3.5 w-3.5" />
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Delete recipe?</DialogTitle>
                  <DialogDescription>
                    Are you sure you want to delete "{recipe.name}"? This action cannot be undone.
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setDeleteOpen(false)}>Cancel</Button>
                  <Button variant="destructive" onClick={() => { onDelete(recipe.id); setDeleteOpen(false) }}>Delete</Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
