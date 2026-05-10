"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

// ====== Canvas (iPhone 6.5"/6.7" — App Store accepted sizes) ===========================
const W = 1284;
const H = 2778;

const IPHONE_SIZES = [
  { label: '6.5"/6.7"', w: 1284, h: 2778 },
  { label: '6.5"', w: 1242, h: 2688 },
] as const;

// ====== iPhone mockup (pre-measured) ===================================================
const MK_W = 1022;
const MK_H = 2082;
const MK_RATIO = MK_W / MK_H;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

function phoneW(cW: number, cH: number, clamp = 0.84) {
  return Math.min(clamp, 0.72 * (cH / cW) * MK_RATIO);
}

// ====== Moments tokens =================================================================
const M = {
  cream: "#FBF6EE",
  ivory: "#F2E9D8",
  coral: "#E8A598",
  coralDark: "#C97F70",
  sage: "#A8B89E",
  denim: "#7A92A8",
  ink: "#3D2E24",
  taupe: "#8B7968",
};

const FF_KR = `"Pretendard Variable", -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", system-ui, sans-serif`;
const FF_SERIF = `var(--font-fraunces), "Times New Roman", serif`;
const FF_HAND = `var(--font-caveat), "Bradley Hand", "Snell Roundhand", cursive`;
const FF_MONO = `ui-monospace, "SF Mono", Menlo, monospace`;

// ====== Image preload (CRITICAL for html-to-image) =====================================
const IMAGE_PATHS = [
  "/mockup.png",
  "/app-icon.png",
  "/screenshots/ko/home.png",
];
const imageCache: Record<string, string> = {};

async function preloadAllImages() {
  await Promise.all(
    IMAGE_PATHS.map(async (path) => {
      try {
        const resp = await fetch(path);
        const blob = await resp.blob();
        const dataUrl = await new Promise<string>((resolve) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.readAsDataURL(blob);
        });
        imageCache[path] = dataUrl;
      } catch {}
    }),
  );
}
function img(path: string): string {
  return imageCache[path] || path;
}

// ====== Paper grain (inline SVG data URI — survives html-to-image) =====================
const grainBg = `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='240' height='240'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='2' seed='4'/><feColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.55 0'/></filter><rect width='100%' height='100%' filter='url(%23n)' opacity='1'/></svg>")`;

function PaperGrain({ opacity = 0.3 }: { opacity?: number }) {
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        pointerEvents: "none",
        opacity,
        backgroundImage: grainBg,
        backgroundSize: "240px 240px",
        mixBlendMode: "multiply",
      }}
    />
  );
}

// ====== Vignette =======================================================================
function Vignette({ strength = 0.12, color = "#3D2E24" }: { strength?: number; color?: string }) {
  const alpha = Math.round(strength * 255).toString(16).padStart(2, "0");
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        pointerEvents: "none",
        background: `radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, ${color}${alpha} 100%)`,
      }}
    />
  );
}

// ====== Phone ==========================================================================
function Phone({
  src,
  alt,
  style,
}: {
  src: string;
  alt: string;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        position: "relative",
        aspectRatio: `${MK_W}/${MK_H}`,
        filter: "drop-shadow(0 24px 56px rgba(61,46,36,0.22)) drop-shadow(0 8px 16px rgba(61,46,36,0.12))",
        ...style,
      }}
    >
      <img
        src={img("/mockup.png")}
        alt=""
        style={{ display: "block", width: "100%", height: "100%" }}
        draggable={false}
      />
      <div
        style={{
          position: "absolute",
          zIndex: 10,
          overflow: "hidden",
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={src}
          alt={alt}
          style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }}
          draggable={false}
        />
      </div>
    </div>
  );
}

// ====== Moments wordmark ===============================================================
function MomentsMark({ size = 64, color = M.ink, dotColor = M.coral }: { size?: number; color?: string; dotColor?: string }) {
  return (
    <span
      style={{
        fontFamily: FF_SERIF,
        fontStyle: "italic",
        fontWeight: 600,
        fontSize: size,
        color,
        letterSpacing: "-0.03em",
        lineHeight: 1,
      }}
    >
      Moments<span style={{ color: dotColor }}>.</span>
    </span>
  );
}

// ====== Polaroid =======================================================================
function Polaroid({
  width,
  rotate = 0,
  caption,
  meta,
  topTape,
  fill = "coral",
  imgSrc,
  style,
}: {
  width: number;
  rotate?: number;
  caption?: string;
  meta?: string;
  topTape?: { color?: "coral" | "sage" | "ivory"; rotate?: number } | false;
  fill?: "coral" | "sage" | "denim" | "ivory" | "image";
  imgSrc?: string;
  style?: React.CSSProperties;
}) {
  const fills: Record<string, string> = {
    coral: `linear-gradient(150deg, #F4C5BA 0%, ${M.coral} 60%, ${M.coralDark} 100%)`,
    sage: `linear-gradient(160deg, #C7D3BD 0%, ${M.sage} 70%, #8DA08A 100%)`,
    denim: `linear-gradient(160deg, #A8BDD0 0%, ${M.denim} 70%, #5E7990 100%)`,
    ivory: `linear-gradient(160deg, #FAF3E5 0%, ${M.ivory} 100%)`,
  };
  const padBottom = caption || meta ? width * 0.18 : width * 0.08;
  return (
    <div
      style={{
        width,
        padding: width * 0.05,
        paddingBottom: padBottom,
        background: "#FAFAF7",
        boxShadow:
          "0 1px 2px rgba(61,46,36,0.08), 0 8px 18px rgba(61,46,36,0.16), 0 24px 48px rgba(61,46,36,0.12)",
        transform: `rotate(${rotate}deg)`,
        borderRadius: 4,
        position: "relative",
        ...style,
      }}
    >
      {topTape && (
        <div
          style={{
            position: "absolute",
            top: -width * 0.05,
            left: "50%",
            transform: `translateX(-50%) rotate(${topTape.rotate ?? -3}deg)`,
            width: width * 0.42,
            height: width * 0.085,
            background:
              topTape.color === "sage"
                ? "rgba(168,184,158,0.78)"
                : topTape.color === "ivory"
                  ? "rgba(242,233,216,0.85)"
                  : "rgba(232,165,152,0.78)",
            boxShadow: "0 1px 3px rgba(61,46,36,0.14)",
          }}
        />
      )}
      <div
        style={{
          width: "100%",
          aspectRatio: "1 / 1.05",
          background: fill === "image" && imgSrc ? `url(${imgSrc})` : fills[fill],
          backgroundSize: "cover",
          backgroundPosition: "center",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {fill === "coral" && (
          <div
            style={{
              position: "absolute",
              top: width * 0.03,
              left: width * 0.03,
              padding: `${width * 0.012}px ${width * 0.025}px`,
              background: "rgba(251,246,238,0.92)",
              color: M.ink,
              fontFamily: FF_MONO,
              fontSize: width * 0.032,
              fontWeight: 700,
              letterSpacing: 1.2,
              borderRadius: 999,
              display: "inline-flex",
              alignItems: "center",
              gap: width * 0.012,
            }}
          >
            <span style={{ width: width * 0.018, height: width * 0.018, borderRadius: "50%", background: M.coralDark, display: "inline-block" }} />
            LIVE
          </div>
        )}
      </div>
      {(caption || meta) && (
        <div style={{ paddingTop: width * 0.04, textAlign: "center" }}>
          {caption && (
            <div
              style={{
                fontFamily: FF_HAND,
                fontSize: width * 0.11,
                fontWeight: 500,
                color: M.ink,
                lineHeight: 1.05,
              }}
            >
              {caption}
            </div>
          )}
          {meta && (
            <div
              style={{
                fontFamily: FF_MONO,
                fontSize: width * 0.034,
                color: M.taupe,
                letterSpacing: 1.6,
                marginTop: width * 0.012,
              }}
            >
              {meta}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ====== Masking tape ===================================================================
function MaskingTape({
  width,
  height,
  rotate = 0,
  tint = "coral",
  style,
}: {
  width: number;
  height: number;
  rotate?: number;
  tint?: "coral" | "sage" | "ivory" | "denim";
  style?: React.CSSProperties;
}) {
  const tintColor =
    tint === "sage"
      ? "rgba(168,184,158,0.8)"
      : tint === "ivory"
        ? "rgba(242,233,216,0.88)"
        : tint === "denim"
          ? "rgba(122,146,168,0.68)"
          : "rgba(232,165,152,0.78)";
  return (
    <div
      style={{
        width,
        height,
        background: tintColor,
        transform: `rotate(${rotate}deg)`,
        boxShadow: "0 1px 3px rgba(61,46,36,0.10), 0 6px 14px rgba(61,46,36,0.06)",
        ...style,
      }}
    />
  );
}

// ====== Stamp badge ====================================================================
function StampBadge({
  text,
  angle = -8,
  color = M.coralDark,
  style,
}: {
  text: string;
  angle?: number;
  color?: string;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        display: "inline-block",
        padding: "10px 22px",
        border: `2px solid ${color}`,
        color,
        fontFamily: FF_MONO,
        fontSize: 18,
        fontWeight: 700,
        letterSpacing: 3,
        transform: `rotate(${angle}deg)`,
        opacity: 0.88,
        ...style,
      }}
    >
      {text}
    </div>
  );
}

// ====== Film strip (slide 3) ===========================================================
function FilmStrip({
  width,
  height,
  style,
}: {
  width: number;
  height: number;
  style?: React.CSSProperties;
}) {
  const sprocketCount = Math.floor(width / 70);
  return (
    <div
      style={{
        width,
        height,
        background: "#1F1A16",
        position: "relative",
        ...style,
      }}
    >
      {[0, 1].map((row) => (
        <div
          key={row}
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: row === 0 ? 0 : "auto",
            bottom: row === 1 ? 0 : "auto",
            height: height * 0.18,
            display: "flex",
            alignItems: "center",
            justifyContent: "space-around",
            background: "#15110E",
          }}
        >
          {Array.from({ length: sprocketCount }).map((_, i) => (
            <div
              key={i}
              style={{
                width: 28,
                height: 36,
                background: M.cream,
                opacity: 0.88,
                borderRadius: 4,
              }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

// ====== Slide types ====================================================================
type SlideProps = { cW: number; cH: number };
type SlideDef = { id: string; component: (p: SlideProps) => React.ReactNode };

const HOME = "/screenshots/ko/home.png";

// ====== Slide 1 — Hero =================================================================
const slide1: SlideDef = {
  id: "01-hero",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.86) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: M.cream,
          overflow: "hidden",
        }}
      >
        <MaskingTape
          width={cW * 0.22}
          height={cW * 0.05}
          rotate={-14}
          tint="coral"
          style={{ position: "absolute", top: cW * 0.06, right: cW * 0.04, zIndex: 5 }}
        />

        <div
          style={{
            position: "absolute",
            top: cW * 0.1,
            left: 0,
            right: 0,
            textAlign: "center",
            zIndex: 4,
          }}
        >
          <div
            style={{
              fontFamily: FF_MONO,
              fontSize: cW * 0.022,
              letterSpacing: cW * 0.006,
              color: M.taupe,
              fontWeight: 700,
              marginBottom: cW * 0.018,
            }}
          >
            MOMENTS · 2026
          </div>
          <MomentsMark size={cW * 0.115} />
        </div>

        <div
          style={{
            position: "absolute",
            top: cW * 0.42,
            left: 0,
            right: 0,
            textAlign: "center",
            zIndex: 4,
            padding: `0 ${cW * 0.07}px`,
          }}
        >
          <div
            style={{
              fontFamily: FF_KR,
              fontSize: cW * 0.092,
              fontWeight: 800,
              lineHeight: 1.12,
              letterSpacing: "-0.035em",
              color: M.ink,
            }}
          >
            1초의 기억이
            <br />
            한 편의 영화로<span style={{ color: M.coral }}>.</span>
          </div>
          <div
            style={{
              width: cW * 0.05,
              height: cW * 0.012,
              borderRadius: 999,
              background: M.coral,
              margin: `${cW * 0.04}px auto 0`,
            }}
          />
        </div>

        <Phone
          src={img(HOME)}
          alt="Moments home"
          style={{
            position: "absolute",
            bottom: 0,
            width: `${fw}%`,
            left: "50%",
            transform: `translateX(-50%) translateY(15%)`,
          }}
        />

        <PaperGrain opacity={0.22} />
        <Vignette strength={0.06} />
      </div>
    );
  },
};

// ====== Slide 2 — Live Photos ==========================================================
const slide2: SlideDef = {
  id: "02-live-photos",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.62) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `linear-gradient(170deg, ${M.ivory} 0%, #EFE5D2 100%)`,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: cW * 0.11,
            left: cW * 0.07,
            right: cW * 0.07,
            zIndex: 5,
            textAlign: "left",
          }}
        >
          <div
            style={{
              fontFamily: FF_MONO,
              fontSize: cW * 0.022,
              letterSpacing: cW * 0.006,
              color: M.coralDark,
              fontWeight: 700,
              marginBottom: cW * 0.022,
            }}
          >
            LIVE PHOTOS · AUTO-MERGE
          </div>
          <div
            style={{
              fontFamily: FF_KR,
              fontSize: cW * 0.092,
              fontWeight: 800,
              lineHeight: 1.12,
              letterSpacing: "-0.035em",
              color: M.ink,
            }}
          >
            라이브 포토만 골라
            <br />
            자연스레 <span style={{ color: M.coralDark }}>이어붙여요</span>.
          </div>
        </div>

        <Phone
          src={img(HOME)}
          alt="Live photo merge"
          style={{
            position: "absolute",
            right: cW * -0.04,
            bottom: cW * -0.08,
            width: `${fw}%`,
            transform: "rotate(5deg)",
            zIndex: 3,
          }}
        />

        <Polaroid
          width={cW * 0.34}
          rotate={-10}
          caption="trip · 01"
          meta="2026.04.21"
          fill="coral"
          topTape={{ color: "ivory", rotate: -2 }}
          style={{ position: "absolute", left: cW * 0.04, top: cW * 0.7, zIndex: 5 }}
        />
        <Polaroid
          width={cW * 0.3}
          rotate={7}
          caption="trip · 02"
          meta="2026.04.22"
          fill="sage"
          style={{ position: "absolute", left: cW * 0.32, top: cW * 1.05, zIndex: 6 }}
        />

        <div
          style={{
            position: "absolute",
            top: cW * 0.55,
            left: cW * 0.07,
            fontFamily: FF_HAND,
            fontSize: cW * 0.052,
            color: M.coralDark,
            transform: "rotate(-4deg)",
            zIndex: 6,
          }}
        >
          ↘ 셔터 누른 1초
        </div>

        <PaperGrain opacity={0.2} />
        <Vignette strength={0.05} />
      </div>
    );
  },
};

// ====== Slide 3 — Timeline =============================================================
const slide3: SlideDef = {
  id: "03-timeline",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.66) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: M.cream,
          overflow: "hidden",
        }}
      >
        <FilmStrip
          width={cW * 1.4}
          height={cW * 0.26}
          style={{
            position: "absolute",
            top: cW * 1.45,
            left: cW * -0.2,
            transform: "rotate(-3deg)",
            zIndex: 1,
            opacity: 0.95,
          }}
        />

        <div
          style={{
            position: "absolute",
            top: cW * 0.11,
            left: cW * 0.07,
            right: cW * 0.07,
            zIndex: 5,
            textAlign: "right",
          }}
        >
          <div
            style={{
              fontFamily: FF_MONO,
              fontSize: cW * 0.022,
              letterSpacing: cW * 0.006,
              color: "#7B8C72",
              fontWeight: 700,
              marginBottom: cW * 0.022,
            }}
          >
            TIMELINE · DATE-SORTED
          </div>
          <div
            style={{
              fontFamily: FF_KR,
              fontSize: cW * 0.092,
              fontWeight: 800,
              lineHeight: 1.12,
              letterSpacing: "-0.035em",
              color: M.ink,
            }}
          >
            촬영한 순서 그대로<span style={{ color: M.coral }}>,</span>
            <br />
            <span style={{ color: "#7B8C72" }}>자동</span> 정렬<span style={{ color: M.coral }}>.</span>
          </div>
        </div>

        {/* Polaroid timeline cascade — left column */}
        <Polaroid
          width={cW * 0.3}
          rotate={-8}
          caption="morning"
          meta="04.21 · 09:14"
          fill="ivory"
          style={{ position: "absolute", left: cW * 0.04, top: cW * 0.62, zIndex: 4 }}
        />
        <Polaroid
          width={cW * 0.32}
          rotate={5}
          caption="lunch"
          meta="04.21 · 12:48"
          fill="coral"
          topTape={{ color: "sage", rotate: 4 }}
          style={{ position: "absolute", left: cW * -0.02, top: cW * 1.04, zIndex: 5 }}
        />
        <Polaroid
          width={cW * 0.3}
          rotate={-4}
          caption="evening"
          meta="04.21 · 19:02"
          fill="denim"
          style={{ position: "absolute", left: cW * 0.06, top: cW * 1.5, zIndex: 4 }}
        />

        {/* Phone — right side, vertically anchored, well visible */}
        <Phone
          src={img(HOME)}
          alt="Timeline"
          style={{
            position: "absolute",
            right: cW * -0.04,
            top: cW * 0.52,
            width: `${fw}%`,
            transform: "rotate(3deg)",
            zIndex: 3,
          }}
        />

        <PaperGrain opacity={0.22} />
        <Vignette strength={0.07} />
      </div>
    );
  },
};

// ====== Slide 4 — Export (dark) ========================================================
const slide4: SlideDef = {
  id: "04-export",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH, 0.78) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `radial-gradient(ellipse at 50% 30%, #4D3A2D 0%, ${M.ink} 60%, #2A1F19 100%)`,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: cW * 0.65,
            left: "50%",
            transform: "translateX(-50%)",
            width: cW * 1.2,
            height: cW * 1.2,
            borderRadius: "50%",
            background: `radial-gradient(circle, rgba(232,165,152,0.45) 0%, rgba(232,165,152,0) 60%)`,
            zIndex: 1,
          }}
        />

        <div
          style={{
            position: "absolute",
            top: cW * 0.12,
            left: 0,
            right: 0,
            textAlign: "center",
            padding: `0 ${cW * 0.07}px`,
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontFamily: FF_MONO,
              fontSize: cW * 0.022,
              letterSpacing: cW * 0.006,
              color: M.coral,
              fontWeight: 700,
              marginBottom: cW * 0.022,
            }}
          >
            EXPORT · ONE TAP
          </div>
          <div
            style={{
              fontFamily: FF_KR,
              fontSize: cW * 0.094,
              fontWeight: 800,
              lineHeight: 1.12,
              letterSpacing: "-0.035em",
              color: M.cream,
            }}
          >
            한 번의 탭으로
            <br />
            나만의 <span style={{ color: M.coral }}>Vlog</span>.
          </div>
        </div>

        <div style={{ position: "absolute", top: cW * 0.55, right: cW * 0.06, zIndex: 6 }}>
          <StampBadge text="EXPORTED · v1" angle={-9} color={M.coral} />
        </div>

        <Phone
          src={img(HOME)}
          alt="Export ready"
          style={{
            position: "absolute",
            bottom: 0,
            width: `${fw}%`,
            left: "50%",
            transform: `translateX(-50%) translateY(13%)`,
            zIndex: 4,
          }}
        />

        <div
          style={{
            position: "absolute",
            top: cW * 1.05,
            left: "50%",
            transform: "translateX(-50%)",
            width: cW * 0.18,
            height: cW * 0.18,
            borderRadius: "50%",
            background: M.coral,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0 12px 36px rgba(232,165,152,0.6)",
            zIndex: 7,
          }}
        >
          <div
            style={{
              width: 0,
              height: 0,
              borderLeft: `${cW * 0.06}px solid ${M.cream}`,
              borderTop: `${cW * 0.038}px solid transparent`,
              borderBottom: `${cW * 0.038}px solid transparent`,
              marginLeft: cW * 0.012,
            }}
          />
        </div>

        <PaperGrain opacity={0.16} />
      </div>
    );
  },
};

// ====== Slide 5 — Mood (no device) =====================================================
const slide5: SlideDef = {
  id: "05-mood",
  component: ({ cW }) => {
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: M.cream,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: cW * 0.11,
            left: "50%",
            transform: "translateX(-50%)",
            width: cW * 0.16,
            height: cW * 0.16,
            borderRadius: cW * 0.036,
            overflow: "hidden",
            boxShadow: "0 4px 12px rgba(61,46,36,0.16), 0 12px 28px rgba(61,46,36,0.10)",
            zIndex: 6,
          }}
        >
          <img src={img("/app-icon.png")} alt="App" style={{ width: "100%", height: "100%", objectFit: "cover" }} draggable={false} />
        </div>

        <div
          style={{
            position: "absolute",
            top: cW * 0.31,
            left: 0,
            right: 0,
            textAlign: "center",
            padding: `0 ${cW * 0.07}px`,
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontFamily: FF_MONO,
              fontSize: cW * 0.022,
              letterSpacing: cW * 0.006,
              color: M.taupe,
              fontWeight: 700,
              marginBottom: cW * 0.022,
            }}
          >
            FOR MEMORIES
          </div>
          <div
            style={{
              fontFamily: FF_KR,
              fontSize: cW * 0.094,
              fontWeight: 800,
              lineHeight: 1.12,
              letterSpacing: "-0.035em",
              color: M.ink,
            }}
          >
            편집하지 않은 듯<span style={{ color: M.coral }}>,</span>
            <br />
            편집한 것<span style={{ color: M.coral }}>.</span>
          </div>
          <div
            style={{
              marginTop: cW * 0.04,
              fontFamily: FF_HAND,
              fontSize: cW * 0.046,
              color: M.taupe,
            }}
          >
            made with moments
          </div>
        </div>

        <Polaroid
          width={cW * 0.32}
          rotate={-11}
          caption="seoul · spring"
          meta="2026.04.21"
          fill="coral"
          topTape={{ color: "ivory", rotate: -3 }}
          style={{ position: "absolute", left: cW * 0.04, top: cW * 0.92, zIndex: 4 }}
        />
        <Polaroid
          width={cW * 0.36}
          rotate={4}
          caption="paper boats"
          meta="2026.04.22"
          fill="denim"
          style={{ position: "absolute", left: cW * 0.36, top: cW * 1.0, zIndex: 5 }}
        />
        <Polaroid
          width={cW * 0.3}
          rotate={9}
          caption="last light"
          meta="2026.04.23"
          fill="sage"
          topTape={{ color: "coral", rotate: 6 }}
          style={{ position: "absolute", right: cW * 0.04, top: cW * 0.86, zIndex: 4 }}
        />
        <Polaroid
          width={cW * 0.3}
          rotate={-5}
          caption="quiet"
          meta="2026.04.24"
          fill="ivory"
          style={{ position: "absolute", left: cW * 0.18, top: cW * 1.45, zIndex: 5 }}
        />
        <Polaroid
          width={cW * 0.32}
          rotate={7}
          caption="home"
          meta="2026.04.25"
          fill="coral"
          style={{ position: "absolute", right: cW * 0.1, top: cW * 1.5, zIndex: 4 }}
        />

        <MaskingTape
          width={cW * 0.18}
          height={cW * 0.04}
          rotate={28}
          tint="sage"
          style={{ position: "absolute", left: cW * 0.04, top: cW * 0.74, zIndex: 6 }}
        />
        <MaskingTape
          width={cW * 0.16}
          height={cW * 0.04}
          rotate={-18}
          tint="denim"
          style={{ position: "absolute", right: cW * 0.06, top: cW * 1.78, zIndex: 6 }}
        />

        <PaperGrain opacity={0.28} />
        <Vignette strength={0.08} />
      </div>
    );
  },
};

const SLIDES: SlideDef[] = [slide1, slide2, slide3, slide4, slide5];

// ====== Preview card with auto-scaling =================================================
function ScreenshotPreview({
  cW,
  cH,
  children,
}: {
  cW: number;
  cH: number;
  children: React.ReactNode;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      const w = el.clientWidth;
      setScale(w / cW);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [cW]);

  return (
    <div
      ref={wrapRef}
      style={{
        width: "100%",
        aspectRatio: `${cW} / ${cH}`,
        position: "relative",
        overflow: "hidden",
        borderRadius: 16,
        boxShadow: "0 4px 16px rgba(0,0,0,0.08)",
        background: M.cream,
      }}
    >
      <div
        style={{
          width: cW,
          height: cH,
          transform: `scale(${scale})`,
          transformOrigin: "top left",
          position: "absolute",
          top: 0,
          left: 0,
        }}
      >
        {children}
      </div>
    </div>
  );
}

// ====== Main page ======================================================================
export default function ScreenshotsPage() {
  const [ready, setReady] = useState(false);
  const [sizeIdx, setSizeIdx] = useState(0);
  const [exporting, setExporting] = useState<string | null>(null);

  useEffect(() => {
    preloadAllImages().then(() => setReady(true));
  }, []);

  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);
  const sizeIdxRef = useRef(0);

  // Keep ref in sync so capture closure always sees the latest size.
  useEffect(() => {
    sizeIdxRef.current = sizeIdx;
  }, [sizeIdx]);

  // Expose a capture API on window for headless automation (puppeteer-core).
  useEffect(() => {
    if (!ready) return;
    async function captureSlideEl(el: HTMLElement, w: number, h: number) {
      el.style.left = "0px";
      el.style.opacity = "1";
      el.style.zIndex = "-1";
      const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };
      await toPng(el, opts);
      const dataUrl = await toPng(el, opts);
      el.style.left = "-9999px";
      el.style.opacity = "0";
      el.style.zIndex = "";
      return dataUrl;
    }
    function nextFrame() {
      return new Promise<void>((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
      );
    }
    (window as unknown as { __capture: (idx?: number) => Promise<unknown> }).__capture = async (sizeIndex?: number) => {
      if (sizeIndex != null && sizeIndex !== sizeIdxRef.current) {
        sizeIdxRef.current = sizeIndex;
        setSizeIdx(sizeIndex);
        await nextFrame();
        await nextFrame();
      }
      const size = IPHONE_SIZES[sizeIdxRef.current];
      const results: Array<{ id: string; w: number; h: number; dataUrl: string }> = [];
      for (let i = 0; i < SLIDES.length; i++) {
        const el = exportRefs.current[i];
        if (!el) continue;
        const dataUrl = await captureSlideEl(el, size.w, size.h);
        results.push({ id: SLIDES[i].id, w: size.w, h: size.h, dataUrl });
      }
      return results;
    };
    (window as unknown as { __sizes: typeof IPHONE_SIZES }).__sizes = IPHONE_SIZES;
    (window as unknown as { __ready: boolean }).__ready = true;
  }, [ready]);

  if (!ready) {
    return (
      <div style={{ padding: 40, fontFamily: FF_KR }}>이미지 로딩 중…</div>
    );
  }

  async function captureSlide(el: HTMLElement, w: number, h: number): Promise<string> {
    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "-1";

    const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };

    await toPng(el, opts);
    const dataUrl = await toPng(el, opts);

    el.style.left = "-9999px";
    el.style.opacity = "0";
    el.style.zIndex = "";
    return dataUrl;
  }

  async function exportAll() {
    const size = IPHONE_SIZES[sizeIdx];
    for (let i = 0; i < SLIDES.length; i++) {
      setExporting(`${i + 1}/${SLIDES.length}`);
      const el = exportRefs.current[i];
      if (!el) continue;
      const dataUrl = await captureSlide(el, size.w, size.h);
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${SLIDES[i].id}-ko-${size.w}x${size.h}.png`;
      a.click();
      await new Promise((r) => setTimeout(r, 300));
    }
    setExporting(null);
  }

  async function exportOne(i: number) {
    const size = IPHONE_SIZES[sizeIdx];
    const el = exportRefs.current[i];
    if (!el) return;
    setExporting(`${i + 1}`);
    const dataUrl = await captureSlide(el, size.w, size.h);
    const a = document.createElement("a");
    a.href = dataUrl;
    a.download = `${SLIDES[i].id}-ko-${size.w}x${size.h}.png`;
    a.click();
    setExporting(null);
  }

  return (
    <div style={{ minHeight: "100vh", background: "#f3f4f6", position: "relative", overflowX: "hidden" }}>
      <div
        style={{
          position: "sticky",
          top: 0,
          zIndex: 50,
          background: "white",
          borderBottom: "1px solid #e5e7eb",
          display: "flex",
          alignItems: "center",
        }}
      >
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            gap: 14,
            padding: "12px 18px",
            overflowX: "auto",
            minWidth: 0,
          }}
        >
          <span style={{ display: "inline-flex", alignItems: "center", gap: 8, whiteSpace: "nowrap" }}>
            <MomentsMark size={20} />
            <span style={{ fontFamily: FF_KR, fontSize: 13, color: M.taupe, fontWeight: 600 }}>App Store · 한국어</span>
          </span>
          <span style={{ fontSize: 12, color: "#6b7280" }}>iPhone 6.9"</span>

          <select
            value={sizeIdx}
            onChange={(e) => setSizeIdx(Number(e.target.value))}
            style={{
              fontSize: 12,
              border: "1px solid #e5e7eb",
              borderRadius: 6,
              padding: "5px 10px",
            }}
          >
            {IPHONE_SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} — {s.w}×{s.h}
              </option>
            ))}
          </select>
        </div>

        <div style={{ flexShrink: 0, padding: "10px 16px", borderLeft: "1px solid #e5e7eb" }}>
          <button
            onClick={exportAll}
            disabled={!!exporting}
            style={{
              padding: "8px 22px",
              background: exporting ? M.coral : M.coralDark,
              color: "white",
              border: "none",
              borderRadius: 8,
              fontSize: 13,
              fontWeight: 700,
              cursor: exporting ? "default" : "pointer",
              whiteSpace: "nowrap",
              letterSpacing: 0.4,
            }}
          >
            {exporting ? `Exporting… ${exporting}` : "Export All"}
          </button>
        </div>
      </div>

      <div
        style={{
          padding: 24,
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))",
          gap: 24,
          maxWidth: 1600,
          margin: "0 auto",
        }}
      >
        {SLIDES.map((slide, i) => (
          <div key={slide.id} style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <ScreenshotPreview cW={W} cH={H}>
              {slide.component({ cW: W, cH: H })}
            </ScreenshotPreview>
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                fontSize: 12,
                color: "#6b7280",
                fontFamily: FF_MONO,
              }}
            >
              <span>{slide.id}</span>
              <button
                onClick={() => exportOne(i)}
                disabled={!!exporting}
                style={{
                  padding: "4px 12px",
                  border: `1px solid ${M.coralDark}`,
                  borderRadius: 6,
                  background: "transparent",
                  color: M.coralDark,
                  fontSize: 11,
                  fontWeight: 700,
                  cursor: exporting ? "default" : "pointer",
                  letterSpacing: 0.5,
                }}
              >
                EXPORT
              </button>
            </div>
          </div>
        ))}
      </div>

      <div style={{ position: "absolute", left: -9999, top: 0, pointerEvents: "none" }}>
        {SLIDES.map((slide, i) => (
          <div
            key={slide.id}
            ref={(el) => {
              exportRefs.current[i] = el;
            }}
            style={{
              width: IPHONE_SIZES[sizeIdx].w,
              height: IPHONE_SIZES[sizeIdx].h,
              position: "absolute",
              left: -9999,
              top: 0,
              opacity: 0,
            }}
          >
            {slide.component({
              cW: IPHONE_SIZES[sizeIdx].w,
              cH: IPHONE_SIZES[sizeIdx].h,
            })}
          </div>
        ))}
      </div>
    </div>
  );
}
