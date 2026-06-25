import {
  UNIONLAB_COMPANY_NAME,
  UNIONLAB_COMPANY_SLOGAN,
  UNIONLAB_GATEWAY_SUBTITLE,
  UNIONLAB_GATEWAY_TITLE,
  UNIONLAB_LOGO_URL,
  UNIONLAB_OFFICIAL_URL,
} from "@/lib/unionlabBrand";
import { Typography } from "antd";

const { Title, Paragraph, Text } = Typography;

export default function LoginPromoPanel() {
  return (
    <div className="flex flex-1 flex-col justify-center px-8 py-12 lg:px-16 xl:px-20 max-w-2xl">
      <img src={UNIONLAB_LOGO_URL} alt={UNIONLAB_COMPANY_NAME} className="h-14 w-auto object-contain mb-8" />

      <Text className="text-sm font-medium tracking-wide text-cyan-700 uppercase mb-3">
        {UNIONLAB_COMPANY_NAME}
      </Text>

      <Title level={2} className="!text-slate-800 !mb-4 !leading-snug">
        {UNIONLAB_COMPANY_SLOGAN}
      </Title>

      <div className="rounded-xl border border-white/60 bg-white/75 backdrop-blur-sm px-6 py-5 shadow-sm">
        <Title level={3} className="!text-cyan-800 !mb-2 !mt-0">
          {UNIONLAB_GATEWAY_TITLE}
        </Title>
        <Paragraph className="!text-slate-600 !mb-0 text-base leading-relaxed">{UNIONLAB_GATEWAY_SUBTITLE}</Paragraph>
      </div>

      <Paragraph className="!mt-6 !mb-0">
        <a
          href={UNIONLAB_OFFICIAL_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="text-cyan-700 hover:text-cyan-900 font-medium"
        >
          访问有临医药官网 →
        </a>
      </Paragraph>
    </div>
  );
}
