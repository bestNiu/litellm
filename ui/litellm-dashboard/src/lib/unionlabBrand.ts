export const UNIONLAB_BRAND_NAME = "unionlabLLM";

/** Replace upstream LiteLLM branding in user-visible labels while keeping API identifiers intact. */
export function brandifyDisplayText(text: string): string {
  return text.replace(/LiteLLM/g, UNIONLAB_BRAND_NAME).replace(/\blitellm\b/g, UNIONLAB_BRAND_NAME);
}
export const UNIONLAB_LOGO_URL =
  "https://unionlab-static.oss-cn-hangzhou.aliyuncs.com/public/llm/union-ai.png";
export const UNIONLAB_LOGIN_BG_URL =
  "https://unionlab-static.oss-cn-hangzhou.aliyuncs.com/public/llm/aibg1.png";

export const UNIONLAB_COMPANY_NAME = "有临医药";
export const UNIONLAB_COMPANY_SLOGAN = "以 AI 赋能生物医药创新，加速药物研发与临床转化";
export const UNIONLAB_GATEWAY_TITLE = "AI Gateway 统一 AI 调度中心";
export const UNIONLAB_GATEWAY_SUBTITLE =
  "集中管理大模型接入、路由调度、权限管控与成本治理，为医药研发提供安全可靠的 AI 基础设施。";
export const UNIONLAB_OFFICIAL_URL = "https://www.union-laboratory.com";
