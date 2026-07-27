import { useState, useEffect } from "react"
import { getAllergens, createAllergen, updateAllergen, deleteAllergen, type Allergen } from "@/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet"
import { toast } from "sonner"
import { Loader2, Plus, Trash2, Pencil } from "lucide-react"

export default function AllergensPage() {
  const [name, setName] = useState("")
  const [desc, setDesc] = useState("")
  const [allergens, setAllergens] = useState<Allergen[]>([])
  const [loading, setLoading] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<Allergen | null>(null)

  useEffect(() => {
    load()
  }, [])

  const load = async () => {
    try {
      setAllergens((await getAllergens()).sort((a, b) => a.name.localeCompare(b.name)))
    } catch {
      setAllergens([])
    }
  }

  const create = async () => {
    if (!name.trim()) return
    setLoading(true)
    try {
      const a = await createAllergen(name.trim(), desc.trim() || undefined)
      setAllergens((prev) => [...prev, a].sort((x, y) => x.name.localeCompare(y.name)))
      setName("")
      setDesc("")
      toast.success("Allergen created!")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!deleteTarget) return
    try {
      await deleteAllergen(deleteTarget.id)
      setAllergens((prev) => prev.filter((a) => a.id !== deleteTarget.id))
      setDeleteTarget(null)
      toast.success("Allergen deleted")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Allergens</h1>
        <p className="text-sm text-muted-foreground mt-1">Manage the allergen list used across products and dishes</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Add Allergen</CardTitle>
          <CardDescription>New allergens become available on every dish and product form</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="aname">Name</Label>
            <Input id="aname" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Sesame seeds" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="adesc">Description (optional)</Label>
            <Textarea id="adesc" value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} />
          </div>
        </CardContent>
        <CardFooter>
          <Button onClick={create} disabled={!name.trim() || loading} className="w-full gap-2">
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            {loading ? "Creating..." : "Add Allergen"}
          </Button>
        </CardFooter>
      </Card>

      {allergens.length === 0 ? (
        <div className="py-12 text-center text-sm text-muted-foreground">No allergens yet. Add one above.</div>
      ) : (
        <div className="space-y-2">
          {allergens.map((a) => (
            <AllergenRow
              key={a.id}
              allergen={a}
              onDelete={() => setDeleteTarget(a)}
              onUpdate={(updated) => setAllergens((prev) => prev.map((x) => (x.id === updated.id ? updated : x)).sort((x, y) => x.name.localeCompare(y.name)))}
            />
          ))}
        </div>
      )}

      <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete allergen?</DialogTitle>
            <DialogDescription>
              "{deleteTarget?.name}" will be removed from every dish and product that references it.
            </DialogDescription>
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

function AllergenRow({
  allergen,
  onDelete,
  onUpdate,
}: {
  allergen: Allergen
  onDelete: () => void
  onUpdate: (a: Allergen) => void
}) {
  const [open, setOpen] = useState(false)
  const [name, setName] = useState(allergen.name)
  const [desc, setDesc] = useState(allergen.description || "")
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (open) {
      setName(allergen.name)
      setDesc(allergen.description || "")
    }
  }, [open, allergen])

  const save = async () => {
    if (!name.trim()) return
    setSaving(true)
    try {
      const updated = await updateAllergen(allergen.id, { name: name.trim(), description: desc.trim() })
      onUpdate(updated)
      setOpen(false)
      toast.success("Allergen updated")
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    } finally {
      setSaving(false)
    }
  }

  return (
    <Card className="group">
      <CardContent className="p-4 flex items-start justify-between gap-4">
        <div className="min-w-0 flex-1 space-y-1">
          <h3 className="text-sm font-medium">{allergen.name}</h3>
          {allergen.description && <p className="text-xs text-muted-foreground">{allergen.description}</p>}
        </div>
        <div className="flex gap-1 shrink-0 opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity">
          <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger render={<Button variant="ghost" size="icon" className="h-8 w-8" />}>
              <Pencil className="h-3.5 w-3.5" />
            </SheetTrigger>
            <SheetContent className="w-full sm:max-w-md">
              <SheetHeader>
                <SheetTitle>Edit Allergen</SheetTitle>
              </SheetHeader>
              <div className="flex-1 space-y-4 px-4">
                <div className="space-y-2">
                  <Label htmlFor={`ed-name-${allergen.id}`}>Name</Label>
                  <Input id={`ed-name-${allergen.id}`} value={name} onChange={(e) => setName(e.target.value)} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor={`ed-desc-${allergen.id}`}>Description</Label>
                  <Textarea id={`ed-desc-${allergen.id}`} value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} />
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
          <Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground hover:text-destructive" onClick={onDelete}>
            <Trash2 className="h-3.5 w-3.5" />
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
