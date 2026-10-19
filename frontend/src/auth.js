import { useCallback, useEffect, useState } from 'react';
import { loginKind, toE164 } from './lib/phone.js';
import { supabase } from './supabase.js';

function authRedirectTo() {
  return `${window.location.origin}/`;
}

// Only a password-reset link asks for a new password.
// Signup confirmation and invites sign the person in and continue.
export function linkNeedsNewPassword(type) {
  return type === 'recovery';
}

/** Pull auth tokens off the URL. Returns true only for a password reset. */
async function consumeAuthRedirect() {
  if (!supabase) return false;
  const url = new URL(window.location.href);
  const hashParams = new URLSearchParams(url.hash.replace(/^#/, ''));
  const code = url.searchParams.get('code');
  const type = hashParams.get('type') || url.searchParams.get('type');
  const needsNewPassword = linkNeedsNewPassword(type);

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    url.searchParams.delete('code');
    url.searchParams.delete('type');
    window.history.replaceState({}, '', `${url.pathname}${url.search}`);
    if (error) throw error;
    return needsNewPassword;
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
    return needsNewPassword;
  }

  return false;
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

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, s) => {
      if (event === 'PASSWORD_RECOVERY') setNeedsPasswordUpdate(true);
      if (event === 'SIGNED_OUT') setNeedsPasswordUpdate(false);
      if (event === 'USER_UPDATED') setNeedsPasswordUpdate(false);
      setSession(s);
    });

    (async () => {
      try {
        const recovered = await consumeAuthRedirect();
        if (cancelled) return;
        if (recovered) setNeedsPasswordUpdate(true);
      } catch (err) {
        if (cancelled) return;
        setLinkError(
          err.message ||
            'That email link could not be used. Request a new one from this page.',
        );
      }

      const { data: { session: s } } = await supabase.auth.getSession();
      if (cancelled) return;
      setSession(s);
      setLoading(false);
    })();

    return () => {
      cancelled = true;
      subscription.unsubscribe();
    };
  }, []);

  const signUp = useCallback(async (identifier, password) => {
    const kind = loginKind(identifier);
    const user = (await supabase.auth.getUser()).data.user;
    if (kind === 'phone') {
      const phone = toE164(identifier);
      if (user?.is_anonymous) {
        const { error } = await supabase.auth.updateUser({ phone, password });
        if (error) throw error;
        return 'signed-in';
      }
      const { data, error } = await supabase.auth.signUp({ phone, password });
      if (error) throw error;
      if (!data.session && data.user) return 'confirm';
      return 'signed-in';
    }
    const email = String(identifier || '').trim();
    if (user?.is_anonymous) {
      const { error } = await supabase.auth.updateUser({ email, password });
      if (error) throw error;
      return;
    }
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo: authRedirectTo() },
    });
    if (error) throw error;
    if (!data.session && data.user) return 'confirm';
    return 'signed-in';
  }, []);

  const signIn = useCallback(async (identifier, password) => {
    if (loginKind(identifier) === 'phone') {
      const { error } = await supabase.auth.signInWithPassword({
        phone: toE164(identifier),
        password,
      });
      if (error) throw error;
      return;
    }
    const { error } = await supabase.auth.signInWithPassword({
      email: String(identifier || '').trim(),
      password,
    });
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