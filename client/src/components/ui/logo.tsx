import { cn } from "@/lib/utils";

export function Logo({ className }: { className?: string }) {
  return (
    <svg 
      className={cn("w-8 h-8", className)}
      viewBox="0 0 100 100" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
    >
      <path 
        d="M20 80 L50 20 L80 80 Z" 
        stroke="currentColor" 
        strokeWidth="8" 
        fill="none"
      />
      <path 
        d="M35 60 L65 60" 
        stroke="currentColor" 
        strokeWidth="8" 
        fill="none"
      />
    </svg>
  );
}
