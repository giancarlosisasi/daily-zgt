import { useLang } from '@rspress/core/runtime';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useT } from '../i18n';
import { clamp, useInView, useTabVisible } from '../motion';
import { createReelAudio, type ReelAudio } from './audio';
import { createRenderer } from './render';
import { Stage } from './Stage';
import { CHAPTERS, DURATION, STAGE_W, STILLS } from './timeline';

type Motion = 'pending' | 'motion' | 'reduced';

interface ReelHandle {
  seek: (seconds: number) => void;
  play: () => void;
  pause: () => void;
  time: () => number;
  playing: () => boolean;
  audio: () => string;
}

declare global {
  interface Window {
    __dzReel?: ReelHandle;
  }
}

function useMotion(): Motion {
  const [motion, setMotion] = useState<Motion>('pending');
  useEffect(() => {
    const query = window.matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setMotion(query.matches ? 'reduced' : 'motion');
    update();
    query.addEventListener('change', update);
    return () => query.removeEventListener('change', update);
  }, []);
  return motion;
}

function useFit(frameRef: React.RefObject<HTMLDivElement | null>, stageRef: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const frame = frameRef.current;
    const stage = stageRef.current;
    if (!frame || !stage) return;
    const fit = () => {
      stage.style.transform = `scale(${frame.clientWidth / STAGE_W})`;
    };
    const observer = new ResizeObserver(fit);
    observer.observe(frame);
    fit();
    return () => observer.disconnect();
  }, [frameRef, stageRef]);
}

const timecode = (seconds: number) => {
  const whole = Math.floor(seconds);
  const frames = Math.floor((seconds - whole) * 60);
  return `${String(whole).padStart(2, '0')}:${String(frames).padStart(2, '0')}`;
};

function Still({ at, label }: { at: number; label: string }) {
  const t = useT();
  const frameRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  useFit(frameRef, stageRef);
  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) return;
    createRenderer(stage)(at);
    stage.dataset.ready = 'true';
  }, [at]);
  return (
    <figure className="dz-still">
      <div className="dz-reel-frame" ref={frameRef} role="img" aria-label={label}>
        <Stage t={t} rootRef={stageRef} />
      </div>
      <figcaption>
        <b>{timecode(at)}</b>
        {label}
      </figcaption>
    </figure>
  );
}

function Storyboard() {
  const t = useT();
  return (
    <div className="dz-reel dz-reel--still" data-reel-mode="reduced">
      <p className="dz-reel-note">{t('reel.reduced')}</p>
      <div className="dz-stills">
        {STILLS.map((still) => (
          <Still key={still.t} at={still.t} label={t(still.key)} />
        ))}
      </div>
    </div>
  );
}

function Player({ active }: { active: boolean }) {
  const t = useT();
  const frameRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const scrubRef = useRef<HTMLInputElement>(null);
  const codeRef = useRef<HTMLSpanElement>(null);
  const chaptersRef = useRef<HTMLDivElement>(null);
  const timeRef = useRef(0);
  const renderRef = useRef<((time: number) => void) | null>(null);
  const audioRef = useRef<ReelAudio | null>(null);
  const soundRef = useRef(false);
  const [wanted, setWanted] = useState(true);
  const [sound, setSound] = useState(false);
  const inView = useInView(frameRef, { threshold: 0.25 });
  const tabVisible = useTabVisible();
  const playing = active && wanted && inView && tabVisible;
  const playingRef = useRef(playing);
  playingRef.current = playing;

  useFit(frameRef, stageRef);

  const paint = useCallback(() => {
    const time = timeRef.current;
    renderRef.current?.(time);
    if (scrubRef.current) scrubRef.current.value = String(Math.round(time * 1000));
    if (codeRef.current) codeRef.current.textContent = `${timecode(time)} / ${timecode(DURATION)}`;
    const buttons = chaptersRef.current?.children;
    if (buttons) {
      let current = 0;
      CHAPTERS.forEach((chapter, index) => {
        if (time >= chapter.t) current = index;
      });
      for (let i = 0; i < buttons.length; i += 1) buttons[i].classList.toggle('is-on', i === current);
    }
  }, []);

  const seek = useCallback(
    (seconds: number) => {
      timeRef.current = clamp(seconds, 0, DURATION - 0.001);
      paint();
      if (soundRef.current && playingRef.current) audioRef.current?.start(timeRef.current);
    },
    [paint],
  );

  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) return;
    renderRef.current = createRenderer(stage);
    stage.dataset.ready = 'true';
    paint();
    return () => {
      renderRef.current = null;
    };
  }, [paint]);

  useEffect(() => {
    if (!playing) return;
    let frame = 0;
    let last: number | null = null;
    const audio = soundRef.current ? audioRef.current : null;
    if (audio) {
      void audio.resume();
      audio.start(timeRef.current);
    }
    let heard: number | null = null;
    let stalled = 0;
    const tick = (now: number) => {
      const live = soundRef.current ? audioRef.current : null;
      const audioTime = live?.time() ?? null;
      const delta = last === null ? 0 : Math.min(0.05, (now - last) / 1000);
      if (live && audioTime !== null && audioTime !== heard) {
        heard = audioTime;
        stalled = 0;
        timeRef.current = audioTime;
        live.pump();
      } else {
        timeRef.current = (timeRef.current + delta) % DURATION;
        stalled += delta;
        if (live && stalled > 0.3) {
          stalled = 0;
          live.start(timeRef.current);
        }
      }
      last = now;
      paint();
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      audioRef.current?.stop();
      audioRef.current?.suspend();
    };
  }, [playing, paint]);

  useEffect(
    () => () => {
      audioRef.current?.close();
      audioRef.current = null;
    },
    [],
  );

  useEffect(() => {
    window.__dzReel = {
      seek: (seconds) => {
        setWanted(false);
        seek(seconds);
      },
      play: () => setWanted(true),
      pause: () => setWanted(false),
      time: () => timeRef.current,
      playing: () => playingRef.current,
      audio: () => audioRef.current?.state() ?? 'none',
    };
    return () => {
      delete window.__dzReel;
    };
  }, [seek]);

  const toggleSound = async () => {
    if (soundRef.current) {
      soundRef.current = false;
      setSound(false);
      audioRef.current?.stop();
      audioRef.current?.suspend();
      return;
    }
    try {
      audioRef.current ??= createReelAudio();
      await audioRef.current.resume();
    } catch {
      return;
    }
    soundRef.current = true;
    setSound(true);
    if (playingRef.current) audioRef.current.start(timeRef.current);
    else setWanted(true);
  };

  return (
    <div className="dz-reel" data-reel-mode="motion">
      <div className="dz-reel-frame" ref={frameRef} role="img" aria-label={t('reel.label')}>
        <div className="dz-reel-poster" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <circle cx="12" cy="12" r="9" />
            <circle cx="12" cy="12" r="5" />
            <circle cx="12" cy="12" r="1.2" fill="currentColor" />
          </svg>
        </div>
        <Stage t={t} rootRef={stageRef} />
      </div>
      <div className="dz-reel-controls">
        <button
          type="button"
          className="dz-reel-btn dz-reel-btn--primary"
          onClick={() => setWanted((current) => !current)}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            {wanted ? <path d="M6 4h4v16H6zM14 4h4v16h-4z" /> : <path d="M7 4l13 8-13 8z" />}
          </svg>
          {wanted ? t('reel.pause') : t('reel.play')}
        </button>
        <button type="button" className={`dz-reel-btn${sound ? ' is-on' : ''}`} onClick={toggleSound}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M4 9v6h4l5 4V5L8 9z" fill="currentColor" />
            {sound ? <path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12" /> : <path d="M17 9l5 6M22 9l-5 6" />}
          </svg>
          {sound ? t('reel.soundOff') : t('reel.soundOn')}
        </button>
        <button
          type="button"
          className="dz-reel-btn"
          onClick={() => {
            seek(0);
            setWanted(true);
          }}
        >
          {t('reel.restart')}
        </button>
        <div className="dz-reel-track">
          <input
            ref={scrubRef}
            type="range"
            min={0}
            max={DURATION * 1000}
            step={1}
            defaultValue={0}
            aria-label={t('reel.position')}
            onInput={(event) => {
              setWanted(false);
              seek(Number(event.currentTarget.value) / 1000);
            }}
          />
          <div className="dz-reel-chapters" ref={chaptersRef}>
            {CHAPTERS.map((chapter) => (
              <button
                key={chapter.key}
                type="button"
                style={{ left: `${(chapter.t / DURATION) * 100}%` }}
                onClick={() => seek(chapter.t)}
              >
                {t(chapter.key)}
              </button>
            ))}
          </div>
        </div>
        <span className="dz-reel-code" ref={codeRef}>
          00:00 / 30:00
        </span>
      </div>
      <p className="dz-reel-note">{t('reel.note')}</p>
    </div>
  );
}

export function Reel() {
  const motion = useMotion();
  const lang = useLang();
  if (motion === 'reduced') return <Storyboard key={lang} />;
  return <Player key={lang} active={motion === 'motion'} />;
}
