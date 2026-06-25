import { cx } from "@/lib/cva.config";
import { UiLoadingSpinner } from "../ui/ui-loading-spinner";

const BRAND_NAME = "unionlabLLM";
const LOGO_URL = "https://unionlab-static.oss-cn-hangzhou.aliyuncs.com/public/llm/union-ai.png";

export default function LoadingScreen() {
  return (
    <div className={cx("h-screen", "flex items-center justify-center gap-4")}>
      <div className="py-2 pr-4 border-r border-r-gray-200">
        <img src={LOGO_URL} alt={BRAND_NAME} className="h-10 object-contain" />
      </div>

      <div className="flex items-center justify-center gap-2">
        <UiLoadingSpinner className="size-4" />
        <span className="text-gray-600 text-sm">Loading...</span>
      </div>
    </div>
  );
}
