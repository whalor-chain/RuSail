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
    inDevelopment: 'в разработке...',
    catalog: 'Каталог',
    searchProduct: 'Найти товар',
    addToCart: 'В корзину',
    betaVersion: 'Вы используете бета-версию приложения',
    feedbackMessage: 'Если заметите ошибки или у вас будут идеи по улучшению, поделитесь обратной связь — это поможет сделать наше приложение лучше!',
    rusadaTest: 'Тест Антидопинг 2025 (РУСАДА)',
    worldSailingSite: 'Сайт "World Sailing"',
    rusadaSite: 'Сайт "ВФПС"',
    appearance: 'Внешний вид',
    winterStarts: 'Зимние Старты',
    rusadaIdTitle: 'ID ВФПС',
    enterRusadaId: 'Введите ваш ID ВФПС',
    rusadaIdExample: 'Например: 12345',
    save: 'Сохранить',
    rusadaIdSaved: 'ID ВФПС сохранен',
    yourId: 'Ваш ID'
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
    inDevelopment: 'in development...',
    catalog: 'Catalog',
    searchProduct: 'Search product',
    addToCart: 'Add to Cart',
    betaVersion: 'You are using the beta version of the app',
    feedbackMessage: 'If you notice any bugs or have ideas for improvement, share your feedback - it will help make our app better!',
    rusadaTest: 'Anti-Doping Test 2025 (RUSADA)',
    worldSailingSite: 'World Sailing Website',
    rusadaSite: 'WFSS Website',
    appearance: 'Appearance',
    winterStarts: 'Winter Starts',
    rusadaIdTitle: 'WFSS ID',
    enterRusadaId: 'Enter your WFSS ID',
    rusadaIdExample: 'Example: 12345',
    save: 'Save',
    rusadaIdSaved: 'WFSS ID saved',
    yourId: 'Your ID'
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