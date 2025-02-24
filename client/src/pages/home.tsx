import { useQuery } from "@tanstack/react-query";
import { Competition } from "@shared/schema";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Logo } from "@/components/ui/logo";
import { Flame } from "lucide-react";

export default function Home() {
  const { data: competitions, isLoading } = useQuery<Competition[]>({
    queryKey: ["/api/competitions/active"],
  });

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center justify-between mb-6">
        <Logo className="text-primary w-12 h-12" />
        <h1 className="text-2xl font-bold">RuSail</h1>
      </div>

      <div className="mb-6">
        <div className="flex items-center gap-2 mb-4">
          <Flame className="text-red-500" />
          <h2 className="text-lg font-semibold">Активные соревнования</h2>
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