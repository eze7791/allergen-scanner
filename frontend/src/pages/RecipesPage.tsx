import { useState, useEffect } from "react"
import { getRecipes, createRecipe, deleteRecipe, getFoodItems, type FoodItem, type Recipe } from "@/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { toast } from "sonner"
import { Loader2, Plus, Trash2, X } from "lucide-react"

export default function RecipesPage() {
  const [name, setName] = useState("")
  const [desc, setDesc] = useState("")
  const [foodItems, setFoodItems] = useState<FoodItem[]>([])
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())
  const [recipe, setRecipe] = useState<Recipe | null>(null)
  const [loading, setLoading] = useState(false)
  const [itemSearch, setItemSearch] = useState("")
  const [deleteOpen, setDeleteOpen] = useState(false)

  useEffect(() => {
    getFoodItems().then(setFoodItems)
    loadLatest()
  }, [])

  const loadLatest = async () => {
    try {
      const recipes = await getRecipes()
      setRecipe(recipes.length ? recipes[recipes.length - 1] : null)
    } catch {
      setRecipe(null)
    }
  }

  const toggleItem = (id: number) => {
    setSelectedIds((prev) => {
      const s = new Set(prev)
      if (s.has(id)) s.delete(id)
      else s.add(id)
      return s
    })
  }

  const create = async () => {
    if (!name.trim() || selectedIds.size === 0) return
    setLoading(true)
    try {
      const r = await createRecipe({
        name: name.trim(),
        description: desc.trim() || undefined,
        food_item_ids: Array.from(selectedIds),
      })
      setRecipe(r)
      setName("")
      setDesc("")
      setSelectedIds(new Set())
      setItemSearch("")
      toast.success("Recipe created!")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!recipe) return
    try {
      await deleteRecipe(recipe.id)
      setRecipe(null)
      setDeleteOpen(false)
      toast.success("Recipe deleted")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    }
  }

  const filteredItems = foodItems.filter(
    (i) => i.name.toLowerCase().includes(itemSearch.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Recipes</h1>
        <p className="text-sm text-muted-foreground mt-1">Create recipes by combining products</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Create Recipe</CardTitle>
          <CardDescription>Combine food items into a recipe to see combined allergens</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Recipe name</Label>
            <Input id="name" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Mac & Cheese" />
          </div>

          <div className="space-y-2">
            <Label htmlFor="desc">Description (optional)</Label>
            <Textarea id="desc" value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} />
          </div>

          <div className="space-y-2">
            <Label>Ingredients</Label>
            <Input
              value={itemSearch}
              onChange={(e) => setItemSearch(e.target.value)}
              placeholder="Search ingredients..."
              className="mb-2"
            />
            <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
              {filteredItems.map((i) => (
                <Badge
                  key={i.id}
                  variant={selectedIds.has(i.id) ? "default" : "outline"}
                  className="cursor-pointer select-none"
                  onClick={() => toggleItem(i.id)}
                >
                  {i.name}
                  {selectedIds.has(i.id) && <X className="ml-1 h-3 w-3" />}
                </Badge>
              ))}
            </div>
            {selectedIds.size > 0 && (
              <p className="text-xs text-muted-foreground">
                {selectedIds.size} ingredient{selectedIds.size > 1 ? "s" : ""} selected
              </p>
            )}
          </div>
        </CardContent>
        <CardFooter>
          <Button
            onClick={create}
            disabled={!name.trim() || selectedIds.size === 0 || loading}
            className="w-full gap-2"
          >
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            {loading ? "Creating..." : "Create Recipe"}
          </Button>
        </CardFooter>
      </Card>

      {recipe ? (
        <Card className="border-l-4 border-l-emerald-500">
          <CardHeader className="flex flex-row items-start justify-between">
            <div>
              <CardTitle className="text-base">{recipe.name}</CardTitle>
              {recipe.description && (
                <CardDescription>{recipe.description}</CardDescription>
              )}
            </div>
            <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
              <DialogTrigger render={<Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground hover:text-destructive shrink-0" />}>
                <Trash2 className="h-4 w-4" />
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Delete recipe?</DialogTitle>
                  <DialogDescription>
                    Are you sure you want to delete "{recipe.name}"?
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setDeleteOpen(false)}>Cancel</Button>
                  <Button variant="destructive" onClick={handleDelete}>Delete</Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label className="text-xs text-muted-foreground font-medium">Ingredients</Label>
              <p className="text-sm mt-1">
                {recipe.items.map((i) => i.name).join(", ")}
              </p>
            </div>
            <Separator />
            <div>
              <Label className="text-xs text-muted-foreground font-medium">Combined Allergens</Label>
              <div className="flex flex-wrap gap-1.5 mt-2">
                {recipe.allergens.length === 0 ? (
                  <Badge variant="secondary">No allergens</Badge>
                ) : (
                  recipe.allergens.map((a) => (
                    <Badge key={a.name} variant="outline" className="px-2.5 py-1.5 h-auto flex-col items-start gap-0">
                      <span className="text-xs font-medium">
                        {a.name}
                        <span className="ml-1 text-[10px] text-muted-foreground font-normal">
                          {a.count}x
                        </span>
                      </span>
                      <span className="text-[10px] text-muted-foreground leading-tight">
                        {a.items.join(", ")}
                      </span>
                    </Badge>
                  ))
                )}
              </div>
              {recipe.allergens.length > 0 && (
                <p className="text-[10px] text-muted-foreground/60 mt-2 leading-tight">
                  To remove allergens, edit or delete the source product
                </p>
              )}
            </div>
          </CardContent>
        </Card>
      ) : (
        <div className="py-12 text-center text-sm text-muted-foreground">
          No recipes yet. Create one above.
        </div>
      )}
    </div>
  )
}
