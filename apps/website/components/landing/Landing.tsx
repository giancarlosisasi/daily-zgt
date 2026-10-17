import './landing.css';
import './page.css';
import './reel/reel.css';
import { DemoProvider } from './DemoContext';
import { Hero } from './Hero';
import { Sections } from './Sections';

export function Landing() {
  return (
    <DemoProvider>
      <div className="dz-landing">
        <Hero />
        <Sections />
      </div>
    </DemoProvider>
  );
}
