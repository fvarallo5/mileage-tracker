import { useCallback, useEffect, useState } from 'react';
import { supabase } from './supabase.js';

function authRedirectTo() {
  return `${window.location.origin}/`;
}

/** Pull recovery / magic-link tokens off the URL before the sign-in screen renders. */
async function consumeAuthRedirect() {
  if (!supabase) return false;
  const url = new URL(window.location.href);
  const hashParams = new URLSearchParams(url.hash.replace(/^#/, ''));
  const code = url.searchParams.get('code');
  const type = hashParams.get('type') || url.searchParams.get('type');
  const isRecovery = type === 'recovery';

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    url.searchParams.delete('code');
    url.searchParams.delete('type');
    window.history.replaceState({}, '', `${url.pathname}${url.search}`);
    if (error) throw error;
    return true;
  }

  const accessToken = hashParams.get('access_token');
  const refreshToken = hashParams.get('refresh_token');
  if (accessToken && refreshToken) {
    const { error } = await supabase.auth.setSession({
      access_token: accessToken,
      refresh_token: refreshToken,
    });
    window.history.replaceState({}, '', `${url.pathname}${url.search}`);
    if (error) throw error;
    return isRecovery || true;
  }

  return isRecovery;
}

export function useAuth() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const [needsPasswordUpdate, setNeedsPasswordUpdate] = useState(false);
  const [linkError, setLinkError] = useState(null);

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      return;
    }

    let cancelled = false;

    (async () => {
      try {
        const recovered = await consumeAuthRedirect();
        if (cancelled) return;
        if (recovered) setNeedsPasswordUpdate(true);
      } catch (err) {
        if (cancelled) return;
        setLinkError(
          err.message ||
            'That reset link could not be used here. Request a new one from this page.',
        );
      }

      const { data: { session: s } } = await supabase.auth.getSession();
      if (cancelled) return;
      setSession(s);
      setLoading(false);
    })();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, s) => {
      if (event === 'PASSWORD_RECOVERY') setNeedsPasswordUpdate(true);
      if (event === 'SIGNED_OUT') setNeedsPasswordUpdate(false);
      if (event === 'USER_UPDATED') setNeedsPasswordUpdate(false);
      setSession(s);
    });

    return () => {
      cancelled = true;
      subscription.unsubscribe();
    };
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

  const requestPasswordReset = useCallback(async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: authRedirectTo(),
    });
    if (error) throw error;
  }, []);

  const updatePassword = useCallback(async (password) => {
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw error;
    setNeedsPasswordUpdate(false);
  }, []);

  const user = session?.user ?? null;

  return {
    session,
    user,
    loading,
    needsPasswordUpdate,
    linkError,
    isSignedIn: Boolean(session),
    isAnonymous: Boolean(user?.is_anonymous),
    userEmail: user?.email ?? null,
    signUp,
    signIn,
    signInAnonymously,
    signOut,
    requestPasswordReset,
    updatePassword,
  };
}