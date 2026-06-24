import { HashRouter, Routes, Route } from "react-router-dom"
import { Toaster } from "sonner"
import AppShell from "@/components/layout/AppShell"
import ScanPage from "@/pages/ScanPage"
import SearchPage from "@/pages/SearchPage"
import RecipesPage from "@/pages/RecipesPage"

export default function App() {
  return (
    <HashRouter>
      <AppShell>
        <Routes>
          <Route path="/" element={<ScanPage />} />
          <Route path="/search" element={<SearchPage />} />
          <Route path="/recipes" element={<RecipesPage />} />
        </Routes>
      </AppShell>
      <Toaster position="bottom-center" richColors />
    </HashRouter>
  )
}
