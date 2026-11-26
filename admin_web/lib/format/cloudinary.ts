/**
 * Cloudinary Delivery URL helper for ProntoChat
 * Strict Transformations are enabled in Cloudinary: all URLs strictly use `t_<variant>`
 */

import { MediaRef } from "@/types/firestore";

export type LogoVariant = "logo_sm" | "logo_lg";

export function resolveLogoUrl(
  logo?: MediaRef | null,
  fallbackUrl?: string | null,
  variant: LogoVariant = "logo_sm"
): string | null {
  const cloudName = process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME || "dj4miyael";

  if (logo && logo.key && logo.key.trim().length > 0) {
    const key = logo.key.trim();
    // Strict named transformation: https://res.cloudinary.com/<cloudName>/image/upload/t_<variant>/<key>
    return `https://res.cloudinary.com/${cloudName}/image/upload/t_${variant}/${key}`;
  }

  if (fallbackUrl && fallbackUrl.trim().length > 0) {
    return fallbackUrl.trim();
  }

  return null;
}

