import Sidebar from "./Sidebar"

export default function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh">
      <Sidebar />
      <main className="flex-1 md:ml-56 pb-14 md:pb-0">
        <div className="mx-auto max-w-2xl px-4 py-6 md:px-8 md:py-8">
          {children}
        </div>
      </main>
    </div>
  )
}
