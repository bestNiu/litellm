import { UNIONLAB_BRAND_NAME, UNIONLAB_LOGO_URL } from "@/lib/unionlabBrand";
import { Typography } from "antd";

type BrandHeaderProps = {
  titleLevel?: 2 | 3 | 5;
  logoClassName?: string;
};

export default function BrandHeader({
  titleLevel = 2,
  logoClassName = "h-16 mx-auto object-contain mb-2",
}: BrandHeaderProps) {
  return (
    <div className="text-center">
      <img src={UNIONLAB_LOGO_URL} alt={UNIONLAB_BRAND_NAME} className={logoClassName} />
      <Typography.Title level={titleLevel}>{UNIONLAB_BRAND_NAME}</Typography.Title>
    </div>
  );
}
