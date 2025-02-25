import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Form, FormControl, FormField, FormItem, FormLabel } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { useToast } from "@/hooks/use-toast";
import { useTranslation } from "@/lib/i18n";
import { ArrowLeft } from "lucide-react";
import { useForm } from "react-hook-form";
import { Link } from "wouter";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";

type IdType = 'own' | 'other';

interface RusadaFormData {
  idType: IdType;
  rusadaId: string;
  name?: string;
  surname?: string;
}

export default function RusadaId() {
  const t = useTranslation();
  const { toast } = useToast();

  const formSchema = z.object({
    idType: z.enum(['own', 'other']),
    rusadaId: z.string()
      .min(1, "ID is required")
      .regex(/^\d+$/, "ID must contain only numbers"),
    name: z.string().optional(),
    surname: z.string().optional(),
  }).refine((data) => {
    if (data.idType === 'other') {
      return data.name && data.surname;
    }
    return true;
  }, {
    message: "Name and surname are required for other athlete's ID",
    path: ["name"],
  });

  const form = useForm<RusadaFormData>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      idType: 'own',
      rusadaId: "",
      name: "",
      surname: "",
    }
  });

  const onSubmit = (data: RusadaFormData) => {
    console.log(data);
    toast({
      title: t('rusadaIdSaved'),
      description: `${t('yourId')}: ${data.rusadaId}${data.name ? ` (${data.surname} ${data.name})` : ''}`,
    });
  };

  const watchIdType = form.watch("idType");

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
                name="idType"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('selectIdType')}</FormLabel>
                    <FormControl>
                      <RadioGroup
                        onValueChange={field.onChange}
                        defaultValue={field.value}
                        className="flex flex-col space-y-2"
                      >
                        <FormItem className="flex items-center space-x-3 space-y-0">
                          <FormControl>
                            <RadioGroupItem value="own" />
                          </FormControl>
                          <FormLabel className="font-normal">
                            {t('ownId')}
                          </FormLabel>
                        </FormItem>
                        <FormItem className="flex items-center space-x-3 space-y-0">
                          <FormControl>
                            <RadioGroupItem value="other" />
                          </FormControl>
                          <FormLabel className="font-normal">
                            {t('otherId')}
                          </FormLabel>
                        </FormItem>
                      </RadioGroup>
                    </FormControl>
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="rusadaId"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t('enterRusadaId')}</FormLabel>
                    <FormControl>
                      <Input 
                        placeholder={t('rusadaIdExample')} 
                        {...field}
                        inputMode="numeric"
                        pattern="\d*"
                      />
                    </FormControl>
                  </FormItem>
                )}
              />

              {watchIdType === 'other' && (
                <>
                  <FormField
                    control={form.control}
                    name="surname"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>{t('enterSurname')}</FormLabel>
                        <FormControl>
                          <Input placeholder={t('surnameExample')} {...field} />
                        </FormControl>
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>{t('enterName')}</FormLabel>
                        <FormControl>
                          <Input placeholder={t('nameExample')} {...field} />
                        </FormControl>
                      </FormItem>
                    )}
                  />
                </>
              )}

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