import { Switch, Route, Router as WouterRouter } from "wouter";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "./lib/queryClient";
import { Toaster } from "@/components/ui/toaster";
import { BottomNav } from "@/components/ui/bottom-nav";
import { useTheme } from "./lib/theme";
import { AuthProvider } from "./hooks/use-auth";
import { useEffect, useState, useCallback } from "react";

import Home from "@/pages/home";
import Calendar from "@/pages/calendar";
import Results from "@/pages/results";
import Profile from "@/pages/profile";
import Shop from "@/pages/shop";
import RusadaId from "@/pages/rusada-id";
import AuthPage from "@/pages/auth";
import NotFound from "@/pages/not-found";
import { ProtectedRoute } from "./components/protected-route";

// Use base path for GitHub Pages
const base = '/RuSail';
const useHashLocation = () => {
  const [hash, setHash] = useState(window.location.hash.replace('#', '') || '/');

  useEffect(() => {
    const handler = () => {
      setHash(window.location.hash.replace('#', '') || '/');
    };
    window.addEventListener('hashchange', handler);
    return () => window.removeEventListener('hashchange', handler);
  }, []);

  const navigate = useCallback((to: string) => {
    window.location.hash = to;
  }, []);

  return [hash, navigate];
};

function Router() {
  return (
    <WouterRouter hook={useHashLocation}>
      <Switch>
        <Route path="/auth" component={AuthPage} />
        <ProtectedRoute path="/" component={Home} />
        <ProtectedRoute path="/calendar" component={Calendar} />
        <ProtectedRoute path="/shop" component={Shop} />
        <ProtectedRoute path="/results" component={Results} />
        <ProtectedRoute path="/profile" component={Profile} />
        <ProtectedRoute path="/rusada-id" component={RusadaId} />
        <Route component={NotFound} />
      </Switch>
    </WouterRouter>
  );
}

function App() {
  const { theme } = useTheme();

  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');

    const handleContextMenu = (e: MouseEvent) => {
      e.preventDefault();
    };
    document.addEventListener('contextmenu', handleContextMenu);

    return () => {
      document.removeEventListener('contextmenu', handleContextMenu);
    };
  }, [theme]);

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <div className="min-h-screen bg-background">
          <Router />
          <BottomNav />
        </div>
        <Toaster />
      </AuthProvider>
    </QueryClientProvider>
  );
}

export default App;