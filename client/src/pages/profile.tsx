import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { FaCheck } from "react-icons/fa";
import { useTheme } from "@/lib/theme";
import { useI18n, useTranslation } from "@/lib/i18n";
import { Moon, Sun, Languages, User } from "lucide-react";
import { Link } from "wouter";
import { useAuth } from "@/hooks/use-auth";

export default function Profile() {
  const { theme, setTheme } = useTheme();
  const { language, setLanguage } = useI18n();
  const t = useTranslation();
  const { user } = useAuth();

  return (
    <div className="p-4 pb-20">
      <div className="flex items-center mb-2">
        <User className="w-8 h-8 text-primary mr-2" />
        <h1 className="text-2xl font-bold">{t('profile')}</h1>
      </div>
      {user && (
        <p className="text-primary font-medium mb-6">@{user.username}</p>
      )}

      <div className="space-y-6">
        <div className="mb-6">
          <h2 className="text-lg font-semibold mb-4">{t('personalData')}</h2>
          <Link href="/rusada-id">
            <a className="block">
              <Button variant="outline" className="w-full mb-4">
                {t('rusadaIdTitle')}
              </Button>
            </a>
          </Link>
        </div>

        <div className="space-y-4">
          <h2 className="text-lg font-semibold">{t('additionalLinks')}</h2>

          <Button variant="outline" className="w-full bg-green-50 border-green-300 text-green-700">
            <FaCheck className="mr-2" />
            {t('rusadaTest')}
          </Button>

          <Button variant="outline" className="w-full bg-purple-50 border-purple-300 text-purple-700">
            {t('worldSailingSite')}
          </Button>

          <Button variant="outline" className="w-full">
            {t('rusadaSite')}
          </Button>
        </div>

        <div className="space-y-4 mt-8">
          <h2 className="text-lg font-semibold">{t('appearance')}</h2>

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