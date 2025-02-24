import { useQuery } from "@tanstack/react-query";
import { Competition } from "@shared/schema";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Logo } from "@/components/ui/logo";
import { Flame } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";

export default function Home() {
  const { data: competitions, isLoading } = useQuery<Competition[]>({
    queryKey: ["/api/competitions/active"],
  });

  const t = useTranslation();

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <Logo className="text-primary w-12 h-12" />
          <h1 className="text-2xl font-bold text-primary">RuSail</h1>
        </div>

        <Popover>
          <PopoverTrigger asChild>
            <Button 
              variant="outline" 
              size="sm"
              className="rounded-full text-xs px-3 py-1 h-auto bg-gray-100 hover:bg-gray-200 border-0"
            >
              beta
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-80 p-4">
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <Logo className="text-primary w-8 h-8" />
                <div>
                  <h3 className="font-medium">RuSail</h3>
                  <p className="text-sm text-muted-foreground">Вы используете бета-версию приложения</p>
                </div>
              </div>
              <p className="text-sm text-gray-600">
                Если заметите ошибки или у вас будут идеи по улучшению, поделитесь обратной связь — это поможет сделать наше приложение лучше!
              </p>
            </div>
          </PopoverContent>
        </Popover>
      </div>

      <div className="mb-6">
        <div className="flex items-center gap-2 mb-4">
          <Flame className="text-red-500" />
          <h2 className="text-lg font-semibold">{t('activeCompetitions')}</h2>
        </div>

        {isLoading ? (
          <Card className="animate-pulse">
            <CardContent className="h-24" />
          </Card>
        ) : (
          competitions?.map((competition) => (
            <Card key={competition.id} className="mb-4">
              <CardHeader>
                <CardTitle>{competition.name}</CardTitle>
              </CardHeader>
              <CardContent>
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