/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
<<<<<<< HEAD
 * @flow
=======
 * @flow strict-local
>>>>>>> fb/0.62-stable
 * @format
 */

'use strict';
const NOT_A_NATIVE_COMPONENT = `
const requireNativeComponent = require('requireNativeComponent');

export default 'Not a view config'
`;

const FULL_NATIVE_COMPONENT = `
// @flow

const codegenNativeCommands = require('codegenNativeCommands');
const codegenNativeComponent = require('codegenNativeComponent');

import type {
  Int32,
  BubblingEventHandler,
  DirectEventHandler,
  WithDefault,
} from 'CodegenFlowtypes';
<<<<<<< HEAD

import type {ViewProps} from 'ViewPropTypes';

interface NativeCommands {
  +hotspotUpdate: (viewRef: React.Ref<'RCTView'>, x: Int32, y: Int32) => void;
  +scrollTo: (viewRef: React.Ref<'RCTView'>, y: Int32, animated: boolean) => void;
}

=======
import type {NativeComponent} from 'codegenNativeComponent';

import type {ViewProps} from 'ViewPropTypes';

type ModuleProps = $ReadOnly<{|
  ...ViewProps,

  // Props
  boolean_default_true_optional_both?: WithDefault<boolean, true>,

  // Events
  onDirectEventDefinedInlineNull: DirectEventHandler<null>,
  onBubblingEventDefinedInlineNull: BubblingEventHandler<null>,
|}>;

type NativeType = NativeComponent<ModuleProps>;

interface NativeCommands {
  +hotspotUpdate: (viewRef: React.ElementRef<NativeType>, x: Int32, y: Int32) => void;
  +scrollTo: (viewRef: React.ElementRef<NativeType>, y: Int32, animated: boolean) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['hotspotUpdate', 'scrollTo'],
});

export default codegenNativeComponent<ModuleProps>('Module', {
  interfaceOnly: true,
  paperComponentName: 'RCTModule',
});
`;

const FULL_NATIVE_COMPONENT_WITH_TYPE_EXPORT = `
// @flow

const codegenNativeCommands = require('codegenNativeCommands');
const codegenNativeComponent = require('codegenNativeComponent');
import type {NativeComponent} from 'codegenNativeComponent';

import type {
  Int32,
  BubblingEventHandler,
  DirectEventHandler,
  WithDefault,
} from 'CodegenFlowtypes';

import type {ViewProps} from 'ViewPropTypes';

>>>>>>> fb/0.62-stable
type ModuleProps = $ReadOnly<{|
  ...ViewProps,

  // Props
  boolean_default_true_optional_both?: WithDefault<boolean, true>,

  // Events
  onDirectEventDefinedInlineNull: DirectEventHandler<null>,
  onBubblingEventDefinedInlineNull: BubblingEventHandler<null>,
|}>;

<<<<<<< HEAD
=======
type NativeType = NativeComponent<ModuleProps>;

interface NativeCommands {
  +hotspotUpdate: (viewRef: React.ElementRef<NativeType>, x: Int32, y: Int32) => void;
  +scrollTo: (viewRef: React.ElementRef<NativeType>, y: Int32, animated: boolean) => void;
}

>>>>>>> fb/0.62-stable
export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['hotspotUpdate', 'scrollTo'],
});

<<<<<<< HEAD
export default codegenNativeComponent<ModuleProps>('Module', {
  interfaceOnly: true,
  paperComponentName: 'RCTModule',
});
=======
export default (codegenNativeComponent<ModuleProps>('Module', {
  interfaceOnly: true,
  paperComponentName: 'RCTModule',
}): NativeType);
>>>>>>> fb/0.62-stable
`;

module.exports = {
  'NotANativeComponent.js': NOT_A_NATIVE_COMPONENT,
  'FullNativeComponent.js': FULL_NATIVE_COMPONENT,
<<<<<<< HEAD
=======
  'FullTypedNativeComponent.js': FULL_NATIVE_COMPONENT_WITH_TYPE_EXPORT,
>>>>>>> fb/0.62-stable
};