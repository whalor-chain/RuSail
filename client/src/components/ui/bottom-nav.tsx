import { Link, useLocation } from "wouter";
import { Home, Calendar, Trophy, User, ShoppingBag } from "lucide-react";
import { useTranslation } from "@/lib/i18n";

export function BottomNav() {
  const [location] = useLocation();
  const t = useTranslation();

  const linkClasses = (path: string) => `
    flex flex-col items-center 
    ${location === path ? "text-primary" : "text-muted-foreground"}
    active:scale-90 transition-transform duration-150
    hover:text-primary/80
  `;

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-background border-t border-border py-2">
      <div className="flex justify-around items-center">
        <Link href="/">
          <a className={linkClasses("/")}>
            <Home size={24} />
            <span className="text-xs mt-1">{t('home')}</span>
          </a>
        </Link>

        <Link href="/calendar">
          <a className={linkClasses("/calendar")}>
            <Calendar size={24} />
            <span className="text-xs mt-1">{t('calendar')}</span>
          </a>
        </Link>

        <Link href="/shop">
          <a className={linkClasses("/shop")}>
            <ShoppingBag size={24} />
            <span className="text-xs mt-1">{t('shop')}</span>
          </a>
        </Link>

        <Link href="/results">
          <a className={linkClasses("/results")}>
            <Trophy size={24} />
            <span className="text-xs mt-1">{t('results')}</span>
          </a>
        </Link>

        <Link href="/profile">
          <a className={linkClasses("/profile")}>
            <User size={24} />
            <span className="text-xs mt-1">{t('profile')}</span>
          </a>
        </Link>
      </div>
    </nav>
  );
}