import { useCallback, useEffect, useState } from 'react';
import { supabase } from './supabase.js';

export function useAuth() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      return;
    }

    supabase.auth.getSession().then(({ data: { session: s } }) => {
      setSession(s);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s);
    });

    return () => subscription.unsubscribe();
  }, []);

  const signUp = useCallback(async (email, password) => {
    const user = (await supabase.auth.getUser()).data.user;
    if (user?.is_anonymous) {
      const { error } = await supabase.auth.updateUser({ email, password });
      if (error) throw error;
      return;
    }
    const { data, error } = await supabase.auth.signUp({ email, password });
    if (error) throw error;
    if (!data.session && data.user) {
      throw new Error('Account created. Check your email to confirm, then sign in.');
    }
  }, []);

  const signIn = useCallback(async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
  }, []);

  const signInAnonymously = useCallback(async () => {
    const { error } = await supabase.auth.signInAnonymously();
    if (error) throw error;
  }, []);

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }, []);

  const user = session?.user ?? null;

  return {
    session,
    user,
    loading,
    isSignedIn: Boolean(session),
    isAnonymous: Boolean(user?.is_anonymous),
    userEmail: user?.email ?? null,
    signUp,
    signIn,
    signInAnonymously,
    signOut,
  };
}