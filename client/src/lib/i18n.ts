import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Language = 'ru' | 'en';

interface I18nStore {
  language: Language;
  setLanguage: (lang: Language) => void;
}

export const translations = {
  ru: {
    home: 'Главная',
    calendar: 'Календарь',
    shop: 'Магазин',
    results: 'Результаты',
    profile: 'Профиль',
    activeCompetitions: 'Активные соревнования',
    personalData: 'Личные данные',
    additionalLinks: 'Дополнительные ссылки',
    theme: 'Тема оформления',
    light: 'Светлая',
    dark: 'Темная',
    language: 'Язык',
    year: 'год',
    inDevelopment: 'в разработке...'
  },
  en: {
    home: 'Home',
    calendar: 'Calendar',
    shop: 'Shop',
    results: 'Results',
    profile: 'Profile',
    activeCompetitions: 'Active Competitions',
    personalData: 'Personal Data',
    additionalLinks: 'Additional Links',
    theme: 'Theme',
    light: 'Light',
    dark: 'Dark',
    language: 'Language',
    year: 'year',
    inDevelopment: 'in development...'
  }
};

export const useI18n = create<I18nStore>()(
  persist(
    (set) => ({
      language: 'ru',
      setLanguage: (language) => set({ language }),
    }),
    {
      name: 'i18n-storage',
    }
  )
);

export const useTranslation = () => {
  const { language } = useI18n();
  return (key: keyof typeof translations.ru) => translations[language][key];
};
