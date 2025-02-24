import { Link, useLocation } from "wouter";
import { Home, Calendar, Trophy, User, ShoppingBag } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { useState } from "react";

export function BottomNav() {
  const [location] = useLocation();
  const t = useTranslation();
  const [pressedItem, setPressedItem] = useState<string | null>(null);

  const linkClasses = (path: string) => `
    flex flex-col items-center 
    ${location === path ? "text-primary" : "text-muted-foreground"}
    ${pressedItem === path ? "scale-85" : "scale-100"}
    transition-transform duration-200 ease-in-out
    touch-action-manipulation
  `;

  const handleTouchStart = (path: string) => {
    setPressedItem(path);
  };

  const handleTouchEnd = () => {
    setPressedItem(null);
  };

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-background border-t border-border py-2">
      <div className="flex justify-around items-center">
        <Link href="/">
          <a 
            className={linkClasses("/")}
            onTouchStart={() => handleTouchStart("/")}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
          >
            <Home size={24} className="pointer-events-none" />
            <span className="text-xs mt-1 pointer-events-none">{t('home')}</span>
          </a>
        </Link>

        <Link href="/calendar">
          <a 
            className={linkClasses("/calendar")}
            onTouchStart={() => handleTouchStart("/calendar")}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
          >
            <Calendar size={24} className="pointer-events-none" />
            <span className="text-xs mt-1 pointer-events-none">{t('calendar')}</span>
          </a>
        </Link>

        <Link href="/shop">
          <a 
            className={linkClasses("/shop")}
            onTouchStart={() => handleTouchStart("/shop")}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
          >
            <ShoppingBag size={24} className="pointer-events-none" />
            <span className="text-xs mt-1 pointer-events-none">{t('shop')}</span>
          </a>
        </Link>

        <Link href="/results">
          <a 
            className={linkClasses("/results")}
            onTouchStart={() => handleTouchStart("/results")}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
          >
            <Trophy size={24} className="pointer-events-none" />
            <span className="text-xs mt-1 pointer-events-none">{t('results')}</span>
          </a>
        </Link>

        <Link href="/profile">
          <a 
            className={linkClasses("/profile")}
            onTouchStart={() => handleTouchStart("/profile")}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
          >
            <User size={24} className="pointer-events-none" />
            <span className="text-xs mt-1 pointer-events-none">{t('profile')}</span>
          </a>
        </Link>
      </div>
    </nav>
  );
}