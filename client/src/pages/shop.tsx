import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Heart, ShoppingBag } from "lucide-react";
import { useState } from "react";
import { useTranslation } from "@/lib/i18n";

interface Product {
  id: number;
  name: string;
  price: number;
  oldPrice?: number;
  image: string;
  isFavorite?: boolean;
}

const initialProducts: Product[] = [
  {
    id: 1,
    name: 'Гидрообувь "Zhik" (Seaboot-400)',
    price: 32990,
    oldPrice: 36990,
    image: '/products/seaboot.jpg',
  },
  {
    id: 2,
    name: 'Кепка "Zhik"',
    price: 3490,
    oldPrice: 3990,
    image: '/products/cap.jpg',
  },
  {
    id: 3,
    name: 'Гидрокостюм "Zhik"',
    price: 47990,
    oldPrice: 54990,
    image: '/products/wetsuit.jpg',
  },
];

export default function Shop() {
  const [searchQuery, setSearchQuery] = useState("");
  const [products, setProducts] = useState(initialProducts);
  const t = useTranslation();

  const toggleFavorite = (productId: number) => {
    setProducts(products.map(product => 
      product.id === productId 
        ? { ...product, isFavorite: !product.isFavorite }
        : product
    ));
  };

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <ShoppingBag className="w-8 h-8 text-green-500" />
          <h1 className="text-2xl font-bold">Каталог</h1>
        </div>
      </div>

      <div className="relative mb-6">
        <Input
          type="search"
          placeholder="Найти товар"
          className="w-full bg-gray-100 dark:bg-gray-800"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>

      <div className="space-y-4">
        {products.map((product) => (
          <div key={product.id} className="flex items-center gap-4 bg-white dark:bg-gray-800 p-4 rounded-lg">
            <img 
              src={product.image} 
              alt={product.name}
              className="w-20 h-20 object-cover rounded-md"
            />
            <div className="flex-1">
              <h3 className="font-medium mb-1">{product.name}</h3>
              <div className="flex items-baseline gap-2">
                <span className="text-lg font-bold">{product.price.toLocaleString()} ₽</span>
                {product.oldPrice && (
                  <span className="text-sm text-gray-500 line-through">
                    {product.oldPrice.toLocaleString()} ₽
                  </span>
                )}
              </div>
            </div>
            <div className="flex flex-col gap-2">
              <button
                onClick={() => toggleFavorite(product.id)}
                className="p-2 rounded-full bg-gray-100 dark:bg-gray-700"
              >
                <Heart 
                  className={`w-5 h-5 ${product.isFavorite ? 'fill-red-500 text-red-500' : 'text-gray-500'}`}
                />
              </button>
              <Button variant="outline" size="sm" className="whitespace-nowrap">
                В корзину
              </Button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}