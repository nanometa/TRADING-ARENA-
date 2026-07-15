"use client";

import { MouseEvent, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  AnimatePresence,
  MotionValue,
  motion,
  useMotionValueEvent,
  useReducedMotion,
  useScroll,
  useTransform,
} from "framer-motion";
import { ArtImage } from "./ArtImage";

interface NavItem {
  label: string;
  href: string;
  sub: string;
  arts: number[];
}

const imageSlots = [
  {
    className: "right-0 top-0 h-[32%] w-[42%]",
    parallax: [24, -18] as const,
    delay: 0,
    zIndex: 10,
  },
  {
    className: "right-0 top-[24%] h-[49%] w-[66%]",
    parallax: [-10, 18] as const,
    delay: 0.07,
    zIndex: 20,
  },
  {
    className: "bottom-0 right-0 h-[37%] w-[92%]",
    parallax: [28, -24] as const,
    delay: 0.14,
    zIndex: 30,
  },
] as const;

export function NavRevealList({ items }: { items: NavItem[] }) {
  const sectionRef = useRef<HTMLDivElement>(null);
  const activeRef = useRef(0);
  const router = useRouter();
  const reduceMotion = useReducedMotion();
  const [active, setActive] = useState(0);
  const [direction, setDirection] = useState(1);
  const [leaving, setLeaving] = useState<string | null>(null);

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end end"],
  });

  useMotionValueEvent(scrollYProgress, "change", (progress) => {
    const next = Math.min(
      items.length - 1,
      Math.max(0, Math.floor(progress * items.length)),
    );

    if (next === activeRef.current) return;

    setDirection(next > activeRef.current ? 1 : -1);
    activeRef.current = next;
    setActive(next);
  });

  function navigate(event: MouseEvent<HTMLAnchorElement>, href: string) {
    if (
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }

    event.preventDefault();
    setLeaving(href);
    window.setTimeout(() => router.push(href), reduceMotion ? 0 : 480);
  }

  const activeItem = items[active];

  return (
    <>
      <div
        ref={sectionRef}
        className="relative hidden border-y border-hairline md:block"
        style={{ height: `${Math.max(400, items.length * 100)}vh` }}
        data-testid="arena-scroll-navigation"
      >
        <div className="sticky top-0 h-screen overflow-hidden bg-black">
          <div className="pointer-events-none absolute inset-x-0 top-0 z-50 flex items-center justify-between px-6 pt-24">
            <span className="text-[10px] uppercase tracking-[0.35em] text-muted">
              Explorer l&apos;arène
            </span>
            <span className="font-mono text-[10px] tracking-[0.2em] text-accent">
              {String(active + 1).padStart(2, "0")} /{" "}
              {String(items.length).padStart(2, "0")}
            </span>
          </div>

          <div className="grid h-full grid-cols-[0.82fr_1.18fr] gap-8 px-6 pb-8 pt-28">
            <div className="relative h-[72vh] self-center overflow-hidden">
              <motion.ul
                className="absolute left-0 top-[42%] w-full"
                animate={{ y: `${active * -25}%` }}
                transition={{
                  duration: reduceMotion ? 0 : 0.78,
                  ease: [0.32, 0.72, 0, 1],
                }}
              >
                {items.map((item, index) => {
                  const isActive = index === active;

                  return (
                    <li
                      key={item.href}
                      className="flex h-[15.5vh] items-center"
                    >
                      <Link
                        href={item.href}
                        onClick={(event) => navigate(event, item.href)}
                        className="group relative block w-full py-2"
                        aria-current={isActive ? "step" : undefined}
                      >
                        <motion.span
                          className="absolute -left-6 top-1/2 h-px bg-accent"
                          animate={{
                            width: isActive ? 18 : 0,
                            opacity: isActive ? 1 : 0,
                          }}
                          transition={{ duration: reduceMotion ? 0 : 0.35 }}
                        />

                        <div className="flex items-end justify-between gap-4">
                          <div className="min-w-0">
                            <span
                              className={`block font-display text-[7vw] uppercase leading-[0.78] tracking-tightest transition-all duration-500 ease-fluid ${
                                isActive
                                  ? "translate-x-2 text-white"
                                  : "text-transparent opacity-20 [-webkit-text-stroke:1.5px_rgba(255,255,255,0.7)]"
                              }`}
                            >
                              {item.label}
                            </span>
                            <span
                              className={`mt-2 block text-[9px] uppercase tracking-[0.25em] transition-all duration-500 ${
                                isActive
                                  ? "translate-x-2 text-white/65"
                                  : "text-white/10"
                              }`}
                            >
                              {item.sub}
                            </span>
                          </div>

                          <span
                            className={`pb-2 font-mono text-[10px] transition-all duration-500 ${
                              isActive
                                ? "-translate-x-2 text-accent"
                                : "text-white/10"
                            }`}
                          >
                            0{index + 1} ↗
                          </span>
                        </div>
                      </Link>
                    </li>
                  );
                })}
              </motion.ul>
            </div>

            <div
              className="relative h-[86vh] self-center overflow-hidden"
              data-testid="active-art-collage"
            >
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_48%,rgba(26,107,74,0.13),transparent_58%)]" />

              <AnimatePresence initial={false} custom={direction}>
                <motion.div
                  key={activeItem.href}
                  className="absolute inset-0"
                  custom={direction}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  variants={{
                    enter: (travelDirection: number) => ({
                      opacity: 0,
                      x: travelDirection * 110,
                    }),
                    center: { opacity: 1, x: 0 },
                    exit: (travelDirection: number) => ({
                      opacity: 0,
                      x: travelDirection * -90,
                    }),
                  }}
                  transition={{
                    duration: reduceMotion ? 0 : 0.68,
                    ease: [0.32, 0.72, 0, 1],
                  }}
                >
                  {activeItem.arts.slice(0, 3).map((art, imageIndex) => (
                    <CollageImage
                      key={`${activeItem.href}-${art}`}
                      art={art}
                      itemLabel={activeItem.label}
                      imageIndex={imageIndex}
                      scrollProgress={scrollYProgress}
                      direction={direction}
                      reducedMotion={Boolean(reduceMotion)}
                    />
                  ))}
                </motion.div>
              </AnimatePresence>

              <div className="pointer-events-none absolute bottom-5 left-5 z-50">
                <span className="font-mono text-[9px] tracking-[0.22em] text-white/30">
                  {activeItem.arts
                    .slice(0, 3)
                    .map((art) => String(art).padStart(2, "0"))
                    .join(" — ")}
                </span>
              </div>

              <motion.div
                className="pointer-events-none absolute bottom-0 left-0 z-50 h-px bg-accent"
                animate={{ width: `${((active + 1) / items.length) * 100}%` }}
                transition={{
                  duration: reduceMotion ? 0 : 0.65,
                  ease: [0.32, 0.72, 0, 1],
                }}
              />
            </div>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {leaving && (
          <motion.div
            className="fixed inset-0 z-[100] flex items-end bg-black px-6 py-10"
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "-100%" }}
            transition={{
              duration: reduceMotion ? 0 : 0.48,
              ease: [0.76, 0, 0.24, 1],
            }}
          >
            <div className="absolute inset-x-0 top-0 h-1 bg-accent" />
            <span className="text-[10px] uppercase tracking-[0.35em] text-white/55">
              Entrée dans l&apos;arène
            </span>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}

function CollageImage({
  art,
  itemLabel,
  imageIndex,
  scrollProgress,
  direction,
  reducedMotion,
}: {
  art: number;
  itemLabel: string;
  imageIndex: number;
  scrollProgress: MotionValue<number>;
  direction: number;
  reducedMotion: boolean;
}) {
  const slot = imageSlots[imageIndex];
  const parallaxY = useTransform(
    scrollProgress,
    [0, 1],
    [slot.parallax[0], slot.parallax[1]],
  );

  return (
    <motion.div
      className={`absolute overflow-hidden bg-surface ${slot.className}`}
      style={{
        y: reducedMotion ? 0 : parallaxY,
        zIndex: slot.zIndex,
      }}
      initial={{
        opacity: 0,
        x: direction * (120 + imageIndex * 45),
        clipPath: "inset(0 0 100% 0)",
      }}
      animate={{
        opacity: 1,
        x: 0,
        clipPath: "inset(0 0 0% 0)",
      }}
      exit={{
        opacity: 0,
        x: direction * (-80 - imageIndex * 35),
      }}
      transition={{
        duration: reducedMotion ? 0 : 0.82,
        delay: reducedMotion ? 0 : slot.delay,
        ease: [0.32, 0.72, 0, 1],
      }}
      data-art-slot={imageIndex + 1}
    >
      <ArtImage
        n={art}
        alt={`${itemLabel} — illustration ${imageIndex + 1}`}
        className="h-full w-full"
        rounded="rounded-none"
      />
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/65 via-transparent to-black/5" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 flex items-end justify-between p-4">
        <span className="text-[8px] uppercase tracking-[0.25em] text-white/70">
          {itemLabel}
        </span>
        <span className="font-mono text-[9px] text-accent">
          {String(art).padStart(2, "0")}
        </span>
      </div>
    </motion.div>
  );
}
