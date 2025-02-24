import { Card, CardContent } from "@/components/ui/card";

export default function Results() {
  return (
    <div className="p-4 pb-20">
      <div className="flex items-center mb-6">
        <img 
          src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAzNiAzNiI+PHBhdGggZmlsbD0iI0ZGQ0MwMCIgZD0iTTM2IDE4YzAgOS45NDEtOC4wNTkgMTgtMTggMTgtOS45NCAwLTE4LTguMDU5LTE4LTE4QzAgOC4wNiA4LjA2IDAgMTggMGM5Ljk0MSAwIDE4IDguMDYgMTggMTgiLz48cGF0aCBmaWxsPSIjNjY5NkVFIiBkPSJNMTggMjRjLTMuMzE0IDAtNi0yLjY4Ni02LTZzMi42ODYtNiA2LTYgNiAyLjY4NiA2IDYtMi42ODYgNi02IDZ6Ii8+PC9zdmc+" 
          alt="Trophy Duck"
          className="w-16 h-16 mb-4"
        />
        <h1 className="text-2xl font-bold">Результаты</h1>
      </div>

      <Card className="mb-4">
        <CardContent className="py-4">
          <h3 className="font-medium">Зимние Старты (04.01.25 - 10.01.25)</h3>
        </CardContent>
      </Card>
    </div>
  );
}
