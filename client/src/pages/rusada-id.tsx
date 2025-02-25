import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Form, FormControl, FormField, FormItem, FormLabel } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";
import { useTranslation } from "@/lib/i18n";
import { ArrowLeft } from "lucide-react";
import { useForm } from "react-hook-form";
import { Link } from "wouter";

interface RusadaFormData {
  rusadaId: string;
}

export default function RusadaId() {
  const t = useTranslation();
  const { toast } = useToast();
  const form = useForm<RusadaFormData>({
    defaultValues: {
      rusadaId: ""
    }
  });

  const onSubmit = (data: RusadaFormData) => {
    console.log(data);
    toast({
      title: t('rusadaIdSaved'),
      description: `${t('yourId')}: ${data.rusadaId}`,
    });
  };

  return (
    <div className="p-4">
      <div className="flex items-center gap-2 mb-6">
        <Link href="/profile">
          <a>
            <ArrowLeft className="w-6 h-6" />
          </a>
        </Link>
        <h1 className="text-xl font-semibold">{t('rusadaIdTitle')}</h1>
      </div>

      <Card>
        <CardContent className="pt-6">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              <FormField
                control={form.control}
                name="rusadaId"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('enterRusadaId')}</FormLabel>
                    <FormControl>
                      <Input placeholder={t('rusadaIdExample')} {...field} />
                    </FormControl>
                  </FormItem>
                )}
              />
              <Button type="submit" className="w-full">
                {t('save')}
              </Button>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}