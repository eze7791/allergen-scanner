import { useState, useRef, useEffect } from "react"
import { scanImage, getAllergens, createAllergen, createFoodItem, type Allergen } from "@/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command"
import { toast } from "sonner"
import { Camera, Check, Loader2, Plus, X } from "lucide-react"

export default function ScanPage() {
  const [name, setName] = useState("")
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [scanning, setScanning] = useState(false)
  const [scanResult, setScanResult] = useState<{ image_path: string } | null>(null)
  const [allAllergens, setAllAllergens] = useState<Allergen[]>([])
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())
  const [addOpen, setAddOpen] = useState(false)
  const [searchQ, setSearchQ] = useState("")

  const canvasRef = useRef<HTMLCanvasElement>(null)
  const imgRef = useRef<HTMLImageElement | null>(null)
  const [crop, setCrop] = useState<{ x: number; y: number; w: number; h: number } | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 })
  const [cropRect, setCropRect] = useState<DOMRect | null>(null)

  useEffect(() => {
    getAllergens().then(setAllAllergens).catch(() => {})
  }, [])

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    if (!f) return
    setFile(f)
    setScanResult(null)
    setSelectedIds(new Set())
    setCrop(null)
    const reader = new FileReader()
    reader.onload = (ev) => {
      const url = ev.target?.result as string
      setPreview(url)
      const img = new Image()
      img.onload = () => {
        imgRef.current = img
        const canvas = canvasRef.current
        if (!canvas) return
        const maxW = 400
        const ratio = Math.min(maxW / img.width, 1)
        canvas.width = img.width * ratio
        canvas.height = img.height * ratio
        const ctx = canvas.getContext("2d")!
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
      }
      img.src = url
    }
    reader.readAsDataURL(f)
  }

  const handleMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current!.getBoundingClientRect()
    setCropRect(rect)
    setIsDragging(true)
    const x = e.clientX - rect.left
    const y = e.clientY - rect.top
    setDragStart({ x, y })
    setCrop({ x, y, w: 0, h: 0 })
  }

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!isDragging || !cropRect) return
    const x = Math.min(dragStart.x, e.clientX - cropRect.left)
    const y = Math.min(dragStart.y, e.clientY - cropRect.top)
    const w = Math.abs(e.clientX - cropRect.left - dragStart.x)
    const h = Math.abs(e.clientY - cropRect.top - dragStart.y)
    setCrop({ x, y, w, h })
  }

  const handleMouseUp = () => {
    setIsDragging(false)
    if (crop && (crop.w < 10 || crop.h < 10)) setCrop(null)
  }

  const doScan = async () => {
    if (!file || !name.trim()) return
    setScanning(true)
    try {
      let f = file
      if (crop && crop.w > 10 && crop.h > 10 && imgRef.current && canvasRef.current) {
        const rect = canvasRef.current.getBoundingClientRect()
        const sx = imgRef.current.width / rect.width
        const sy = imgRef.current.height / rect.height
        const c = document.createElement("canvas")
        c.width = crop.w * sx
        c.height = crop.h * sy
        c.getContext("2d")!.drawImage(imgRef.current, crop.x * sx, crop.y * sy, crop.w * sx, crop.h * sy, 0, 0, crop.w * sx, crop.h * sy)
        const blob = await new Promise<Blob>((res) => c.toBlob((b) => res(b!), "image/jpeg", 0.92))
        f = new File([blob], "crop.jpg", { type: "image/jpeg" })
      }
      const data = await scanImage(f)
      setScanResult(data)
      setAllAllergens(data.all_allergens)
      setSelectedIds(new Set(data.detected_allergens.map((a: Allergen) => a.id)))
      toast.success("Scan complete", { description: `${data.detected_allergens.length} allergens detected` })
    } catch (err) {
      toast.error("Scan failed", { description: (err as Error).message })
    } finally {
      setScanning(false)
    }
  }

  const toggleAllergen = (id: number) => {
    setSelectedIds((prev) => {
      const s = new Set(prev)
      if (s.has(id)) s.delete(id)
      else s.add(id)
      return s
    })
  }

  const createAndAdd = async (name: string) => {
    try {
      const a = await createAllergen(name)
      setAllAllergens((prev) => [...prev, a])
      setSelectedIds((prev) => new Set(prev).add(a.id))
      setAddOpen(false)
      setSearchQ("")
      toast.success(`Created "${a.name}"`)
    } catch (err) {
      toast.error("Error", { description: (err as Error).message })
    }
  }

  const saveItem = async () => {
    if (!name.trim() || !scanResult) return
    setLoading(true)
    try {
      await createFoodItem({
        name: name.trim(),
        description: "Scanned from image",
        category: "Scanned",
        image_path: scanResult.image_path,
        allergen_ids: Array.from(selectedIds),
      })
      toast.success("Saved!", { description: "Food item created successfully" })
      setName("")
      setFile(null)
      setPreview(null)
      setScanResult(null)
      setSelectedIds(new Set())
      setCrop(null)
    } catch (err) {
      toast.error("Error saving", { description: (err as Error).message })
    } finally {
      setLoading(false)
    }
  }

  const selectedAllergens = allAllergens.filter((a) => selectedIds.has(a.id))
  const availableAllergens = allAllergens.filter((a) => !selectedIds.has(a.id))

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Scan Product</h1>
        <p className="text-sm text-muted-foreground mt-1">Take a photo of the ingredients label to detect allergens</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Product Details</CardTitle>
          <CardDescription>Enter the product name and upload a photo of the ingredients</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Product name</Label>
            <Input id="name" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Nutella" />
          </div>

          <div className="space-y-2">
            <Label>Ingredients photo</Label>
            <div className="flex items-center gap-3">
              <Button variant="outline" size="sm" className="gap-2 cursor-pointer" render={<label />}>
                <Camera className="h-4 w-4" />
                {file ? "Change photo" : "Choose photo"}
                <input type="file" accept="image/*" capture="environment" onChange={handleFile} className="hidden" />
              </Button>
              {file && (
                <span className="text-xs text-muted-foreground">{file.name}</span>
              )}
            </div>
            {preview && (
              <div className="relative mt-3 select-none touch-none">
                <canvas
                  ref={canvasRef}
                  className="w-full rounded-lg border"
                  onMouseDown={handleMouseDown}
                  onMouseMove={handleMouseMove}
                  onMouseUp={handleMouseUp}
                  onMouseLeave={handleMouseUp}
                />
                {crop && crop.w > 0 && (
                  <div
                    className="absolute border-2 border-dashed border-primary bg-primary/10 pointer-events-none rounded"
                    style={{ left: crop.x, top: crop.y, width: crop.w, height: crop.h }}
                  />
                )}
              </div>
            )}
          </div>
        </CardContent>
        <CardFooter>
          <Button onClick={doScan} disabled={!file || !name.trim() || scanning} className="w-full gap-2">
            {scanning ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            {scanning ? "Scanning..." : "Scan & Review"}
          </Button>
        </CardFooter>
      </Card>

      {scanResult && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Review Allergens</CardTitle>
            <CardDescription>Adjust detected allergens before saving</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label className="text-sm font-medium">Detected allergens</Label>
              <div className="mt-2 flex flex-wrap gap-1.5">
                {selectedAllergens.length === 0 ? (
                  <span className="text-xs text-muted-foreground italic">None selected</span>
                ) : (
                  selectedAllergens.map((a) => (
                    <Badge key={a.id} variant="secondary" className="gap-1 pl-2 pr-1.5 py-1">
                      {a.name}
                      <button onClick={() => toggleAllergen(a.id)} className="ml-0.5 hover:text-destructive cursor-pointer">
                        <X className="h-3 w-3" />
                      </button>
                    </Badge>
                  ))
                )}
              </div>
            </div>

            <div>
              <Label className="text-sm font-medium">Add more allergens</Label>
              <div className="mt-2">
                <Popover open={addOpen} onOpenChange={setAddOpen}>
                  <PopoverTrigger render={<Button variant="outline" size="sm" className="gap-2" />}>
                    <Plus className="h-3.5 w-3.5" />
                    Add allergen
                  </PopoverTrigger>
                  <PopoverContent className="w-64 p-0" align="start">
                    <Command>
                      <CommandInput
                        placeholder="Search allergens..."
                        value={searchQ}
                        onValueChange={setSearchQ}
                      />
                      <CommandList>
                        <CommandEmpty>
                          <button
                            onClick={() => searchQ.trim() && createAndAdd(searchQ.trim())}
                            className="w-full px-3 py-2 text-left text-sm text-primary font-medium hover:bg-accent rounded-sm cursor-pointer"
                          >
                            Create "{searchQ.trim()}"
                          </button>
                        </CommandEmpty>
                        <CommandGroup>
                          {availableAllergens.map((a) => (
                            <CommandItem
                              key={a.id}
                              value={a.name}
                              onSelect={() => {
                                setSelectedIds((prev) => new Set(prev).add(a.id))
                                setAddOpen(false)
                                setSearchQ("")
                              }}
                            >
                              <Check className="mr-2 h-3.5 w-3.5 opacity-0" />
                              {a.name}
                            </CommandItem>
                          ))}
                        </CommandGroup>
                      </CommandList>
                    </Command>
                  </PopoverContent>
                </Popover>
              </div>
            </div>
          </CardContent>
          <CardFooter>
            <Button onClick={saveItem} disabled={loading || !name.trim()} className="w-full gap-2">
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
              {loading ? "Saving..." : "Confirm & Save"}
            </Button>
          </CardFooter>
        </Card>
      )}
    </div>
  )
}
