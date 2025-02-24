import { Link, useLocation } from "wouter";
import { Home, Calendar, Trophy, User, ShoppingBag } from "lucide-react";
import { useTranslation } from "@/lib/i18n";

export function BottomNav() {
  const [location] = useLocation();
  const t = useTranslation();

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-background border-t border-border py-2">
      <div className="flex justify-around items-center">
        <Link href="/">
          <a className={`flex flex-col items-center ${location === "/" ? "text-primary" : "text-muted-foreground"}`}>
            <Home size={24} />
            <span className="text-xs mt-1">{t('home')}</span>
          </a>
        </Link>

        <Link href="/calendar">
          <a className={`flex flex-col items-center ${location === "/calendar" ? "text-primary" : "text-muted-foreground"}`}>
            <Calendar size={24} />
            <span className="text-xs mt-1">{t('calendar')}</span>
          </a>
        </Link>

        <Link href="/shop">
          <a className={`flex flex-col items-center ${location === "/shop" ? "text-primary" : "text-muted-foreground"}`}>
            <ShoppingBag size={24} />
            <span className="text-xs mt-1">{t('shop')}</span>
          </a>
        </Link>

        <Link href="/results">
          <a className={`flex flex-col items-center ${location === "/results" ? "text-primary" : "text-muted-foreground"}`}>
            <Trophy size={24} />
            <span className="text-xs mt-1">{t('results')}</span>
          </a>
        </Link>

        <Link href="/profile">
          <a className={`flex flex-col items-center ${location === "/profile" ? "text-primary" : "text-muted-foreground"}`}>
            <User size={24} />
            <span className="text-xs mt-1">{t('profile')}</span>
          </a>
        </Link>
      </div>
    </nav>
  );
}