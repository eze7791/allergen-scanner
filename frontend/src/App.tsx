import { useEffect, useState } from "react"
import { HashRouter, Routes, Route } from "react-router-dom"
import { Toaster } from "sonner"
import AppShell from "@/components/layout/AppShell"
import ScanPage from "@/pages/ScanPage"
import SearchPage from "@/pages/SearchPage"
import RecipesPage from "@/pages/RecipesPage"
import OnboardingPage from "@/pages/OnboardingPage"
import { getSession, type AuthSession } from "@/api"

export default function App() {
  const [session, setSessionState] = useState<AuthSession | null>(() => getSession())

  useEffect(() => {
    const onChange = () => setSessionState(getSession())
    window.addEventListener("auth-changed", onChange)
    return () => window.removeEventListener("auth-changed", onChange)
  }, [])

  return (
    <HashRouter>
      {session ? (
        <AppShell>
          <Routes>
            <Route path="/" element={<SearchPage />} />
            <Route path="/recipes" element={<RecipesPage />} />
            <Route path="/scan" element={<ScanPage />} />
          </Routes>
        </AppShell>
      ) : (
        <OnboardingPage />
      )}
      <Toaster position="bottom-center" richColors />
    </HashRouter>
  )
}
