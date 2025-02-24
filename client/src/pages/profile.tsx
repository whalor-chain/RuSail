import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { FaCheck } from "react-icons/fa";
import { useTheme } from "@/lib/theme";
import { useI18n, useTranslation } from "@/lib/i18n";
import { Moon, Sun, Languages, User } from "lucide-react";

export default function Profile() {
  const { theme, setTheme } = useTheme();
  const { language, setLanguage } = useI18n();
  const t = useTranslation();

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center mb-6">
        <User className="w-8 h-8 text-primary mr-2" />
        <h1 className="text-2xl font-bold">{t('profile')}</h1>
      </div>

      <div className="space-y-6">
        <div className="mb-6">
          <h2 className="text-lg font-semibold mb-4">{t('personalData')}</h2>
          <Button variant="outline" className="w-full mb-4">
            ID ВФПС
          </Button>
        </div>

        <div className="space-y-4">
          <h2 className="text-lg font-semibold">{t('additionalLinks')}</h2>

          <Button variant="outline" className="w-full bg-green-50 border-green-300 text-green-700">
            <FaCheck className="mr-2" />
            Тест Антидопинг 2025 (РУСАДА)
          </Button>

          <Button variant="outline" className="w-full bg-purple-50 border-purple-300 text-purple-700">
            World Sailing
          </Button>

          <Button variant="outline" className="w-full">
            ВФПС
          </Button>
        </div>

        {/* Appearance Section */}
        <div className="space-y-4 mt-8">
          <h2 className="text-lg font-semibold">Внешний вид</h2>

          {/* Theme Switcher */}
          <div className="flex gap-2">
            <Button 
              variant={theme === 'light' ? 'default' : 'outline'}
              onClick={() => setTheme('light')}
              className="flex-1"
            >
              <Sun className="mr-2 h-4 w-4" />
              {t('light')}
            </Button>
            <Button 
              variant={theme === 'dark' ? 'default' : 'outline'}
              onClick={() => setTheme('dark')}
              className="flex-1"
            >
              <Moon className="mr-2 h-4 w-4" />
              {t('dark')}
            </Button>
          </div>

          {/* Language Switcher */}
          <div className="flex gap-2">
            <Button 
              variant={language === 'ru' ? 'default' : 'outline'}
              onClick={() => setLanguage('ru')}
              className="flex-1"
            >
              <Languages className="mr-2 h-4 w-4" />
              Русский
            </Button>
            <Button 
              variant={language === 'en' ? 'default' : 'outline'}
              onClick={() => setLanguage('en')}
              className="flex-1"
            >
              <Languages className="mr-2 h-4 w-4" />
              English
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}