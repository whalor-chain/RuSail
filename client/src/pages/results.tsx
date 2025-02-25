import { Card, CardContent } from "@/components/ui/card";
import { Trophy, ExternalLink } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { Button } from "@/components/ui/button";

export default function Results() {
  const t = useTranslation();

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center mb-6">
        <Trophy className="w-8 h-8 text-yellow-500 mr-2" />
        <h1 className="text-2xl font-bold">{t('results')}</h1>
      </div>

      <Card className="mb-4">
        <CardContent className="py-4">
          <h3 className="font-medium">{t('winterStarts')} (04.01.25 - 10.01.25)</h3>
          <p className="text-sm text-gray-600 mt-2">
            г. Сочи, ул. Бзугу, 9
          </p>
          <div className="mt-4">
            <p className="text-sm font-medium mb-1">Класс Финн:</p>
            <p className="text-sm text-gray-600">1. Иванов Иван</p>
            <p className="text-sm text-gray-600">2. Петров Петр</p>
            <p className="text-sm text-gray-600">3. Сидоров Сидор</p>
          </div>
          <Button 
            variant="outline" 
            size="sm" 
            className="w-full mt-4"
            onClick={() => window.open('https://rusyf.ru/results', '_blank')}
          >
            <ExternalLink className="w-4 h-4 mr-2" />
            {t('viewFullResults')}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}