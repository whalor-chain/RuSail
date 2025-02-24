import { useQuery } from "@tanstack/react-query";
import { Competition } from "@shared/schema";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { useTranslation } from "@/lib/i18n";
import { Calendar as CalendarIcon } from "lucide-react";

export default function Calendar() {
  const [selectedYear, setSelectedYear] = useState(2024);
  const t = useTranslation();

  const { data: competitions, isLoading } = useQuery<Competition[]>({
    queryKey: ["/api/competitions", selectedYear],
  });

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center mb-6">
        <CalendarIcon className="w-8 h-8 text-red-500 mr-2" />
        <h1 className="text-2xl font-bold">{t('calendar')}</h1>
      </div>

      <div className="mb-6">
        <h2 className="text-lg mb-4">{t('year')}</h2>
        <div className="flex gap-4 mb-6">
          <Button 
            variant={selectedYear === 2024 ? "default" : "outline"}
            onClick={() => setSelectedYear(2024)}
            className="flex-1"
          >
            2024 ({t('inDevelopment')})
          </Button>
          <Button 
            variant={selectedYear === 2025 ? "default" : "outline"}
            onClick={() => setSelectedYear(2025)}
            className="flex-1"
          >
            2025
          </Button>
        </div>

        {isLoading ? (
          <Card className="animate-pulse">
            <CardContent className="h-24" />
          </Card>
        ) : (
          competitions?.map((competition) => (
            <Card key={competition.id} className="mb-4">
              <CardContent className="py-4">
                <p className="font-medium">{competition.name}</p>
                <p className="text-sm text-gray-600">{competition.location}</p>
                <p className="text-sm text-gray-600">
                  {new Date(competition.startDate).toLocaleDateString("ru-RU")} - {" "}
                  {new Date(competition.endDate).toLocaleDateString("ru-RU")}
                </p>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}