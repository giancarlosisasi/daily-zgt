import {
  createContext,
  useContext,
  useEffect,
  useReducer,
  useState,
  type Dispatch,
  type ReactNode,
} from 'react';
import { initialState, reducer, type Action, type DemoState } from './model';
import { tokenMs } from './tokens';

interface DemoValue {
  state: DemoState;
  dispatch: Dispatch<Action>;
  reduced: boolean;
}

const DemoContext = createContext<DemoValue | null>(null);

export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const query = window.matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setReduced(query.matches);
    update();
    query.addEventListener('change', update);
    return () => query.removeEventListener('change', update);
  }, []);
  return reduced;
}

export function DemoProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, undefined, initialState);
  const reduced = useReducedMotion();

  useEffect(() => {
    if (!state.leaving) return;
    const id = state.leaving;
    const timer = setTimeout(() => dispatch({ type: 'finish', id }), reduced ? 0 : tokenMs('--duration-slow'));
    return () => clearTimeout(timer);
  }, [state.leaving, reduced]);

  useEffect(() => {
    if (!state.undo) return;
    const token = state.undo.token;
    const timer = setTimeout(() => dispatch({ type: 'clearUndo', token }), tokenMs('--duration-undo'));
    return () => clearTimeout(timer);
  }, [state.undo]);

  useEffect(() => {
    if (!state.highlight) return;
    const id = state.highlight;
    const timer = setTimeout(() => dispatch({ type: 'clearHighlight', id }), tokenMs('--duration-highlight'));
    return () => clearTimeout(timer);
  }, [state.highlight]);

  useEffect(() => {
    if (!state.toast) return;
    const token = state.toast;
    const timer = setTimeout(() => dispatch({ type: 'clearToast', token }), 4500);
    return () => clearTimeout(timer);
  }, [state.toast]);

  return (
    <DemoContext.Provider value={{ state, dispatch, reduced }}>
      {children}
    </DemoContext.Provider>
  );
}

export function useDemo(): DemoValue {
  const value = useContext(DemoContext);
  if (!value) throw new Error('useDemo needs a DemoProvider');
  return value;
}
