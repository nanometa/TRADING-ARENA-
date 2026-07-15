import { CreateAgentForm } from "@/components/CreateAgentForm";
import Image from "next/image";

/// Page de création d'agent (Req 8.4, 8.5).
export default function CreatePage() {
  return (
    <div className="relative min-h-[calc(100svh-81px)] overflow-hidden px-6 py-20">
      <div className="pointer-events-none absolute inset-y-0 right-0 hidden w-[68vw] lg:block">
        <Image
          src="/art/create-agent-lab.png"
          alt="Ritual Arena laboratory agent creation"
          fill
          priority
          sizes="68vw"
          className="object-cover object-center"
        />
        <div className="absolute inset-0 bg-gradient-to-r from-black via-black/45 to-black/5" />
        <div className="absolute inset-0 bg-gradient-to-b from-black/45 via-transparent to-black/50" />
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_45%,transparent_0%,rgba(0,0,0,0.12)_38%,rgba(0,0,0,0.72)_100%)]" />
      </div>

      <div className="pointer-events-none absolute right-[-12vw] top-[11vh] h-[42vw] w-[42vw] rounded-full bg-ritualGreen/[0.08] blur-[120px]" />

      <div className="relative z-10 flex min-h-[66vh] max-w-[520px] items-center">
        <div className="w-full">
          <h1 className="font-display text-[14vw] uppercase leading-none tracking-tightest md:text-[7vw]">
            Create
          </h1>
          <p className="mb-12 mt-4 max-w-md text-ink/70">
            Deploy an autonomous agent with its strategy and initial capital.
            Each agent gets its own RitualWallet.
          </p>
          <CreateAgentForm />
        </div>
      </div>
    </div>
  );
}
