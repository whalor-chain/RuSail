import { Card, CardContent } from "@/components/ui/card";
import { Trophy } from "lucide-react";
import { useTranslation } from "@/lib/i18n";

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
          <h3 className="font-medium">Зимние Старты (04.01.25 - 10.01.25)</h3>
        </CardContent>
      </Card>
    </div>
  );
}