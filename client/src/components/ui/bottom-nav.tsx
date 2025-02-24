import { Link, useLocation } from "wouter";
import { Home, Calendar, Trophy, User, ShoppingBag } from "lucide-react";

export function BottomNav() {
  const [location] = useLocation();

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 py-2">
      <div className="flex justify-around items-center">
        <Link href="/">
          <a className={`flex flex-col items-center ${location === "/" ? "text-primary" : "text-gray-500"}`}>
            <Home size={24} />
            <span className="text-xs mt-1">Главная</span>
          </a>
        </Link>
        
        <Link href="/calendar">
          <a className={`flex flex-col items-center ${location === "/calendar" ? "text-primary" : "text-gray-500"}`}>
            <Calendar size={24} />
            <span className="text-xs mt-1">Календарь</span>
          </a>
        </Link>

        <Link href="/shop">
          <a className={`flex flex-col items-center ${location === "/shop" ? "text-primary" : "text-gray-500"}`}>
            <ShoppingBag size={24} />
            <span className="text-xs mt-1">Магазин</span>
          </a>
        </Link>

        <Link href="/results">
          <a className={`flex flex-col items-center ${location === "/results" ? "text-primary" : "text-gray-500"}`}>
            <Trophy size={24} />
            <span className="text-xs mt-1">Результаты</span>
          </a>
        </Link>

        <Link href="/profile">
          <a className={`flex flex-col items-center ${location === "/profile" ? "text-primary" : "text-gray-500"}`}>
            <User size={24} />
            <span className="text-xs mt-1">Профиль</span>
          </a>
        </Link>
      </div>
    </nav>
  );
}
