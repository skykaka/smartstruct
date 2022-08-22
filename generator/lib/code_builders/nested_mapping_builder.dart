// Sometimes we need to pass some variable to the static function just like "this pointer".
// We can use the named parameters to implement the goal.
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';
import 'package:smartstruct_generator/models/source_assignment.dart';

import '../models/RefChain.dart';

Expression generateNestedMapping(
  ClassElement abstractMapper, 
  DartType targetType, 
  SourceAssignment sourceAssignment,
  Expression expression
) {

  // found a mapping method in the class which will map the source to target
  final matchingMappingMethods = findMatchingMappingMethods(abstractMapper, targetType, sourceAssignment.field!.type);
  

  if (matchingMappingMethods.isEmpty) {
    return expression;
  }

  final matchingMappingMethod = matchingMappingMethods.first;

  return _generateNestedMapping(
    matchingMappingMethod, 
    sourceAssignment.refChain!,
  );
}

Reference generateNestedMappingLambda(
  DartType inputType,
  MethodElement nestedMapping,
) {

  if(
    _isTypeNullable(inputType) && 
    !isNestedMappingSourceNullable(nestedMapping)
  ) {
    return refer('''
      (x) => x == null ? null : ${nestedMapping.name}(x)
    ''');
  }

  return refer('''
    (x) => ${nestedMapping.name}(x)
  ''');
}

bool isNestedMappingSourceNullable(MethodElement nestedMapping) {
  return _isTypeNullable(nestedMapping.parameters.first.type);
}

bool _isTypeNullable(DartType type) {
  return type.nullabilitySuffix == NullabilitySuffix.question;
}

Expression generateNestedMappingForFunctionMapping(
  ExecutableElement sourceFunction,
  ClassElement abstractMapper,
  VariableElement targetField,
  Expression sourceFieldAssignment,
) {
  final returnType = sourceFunction.returnType;
  final matchingMappingMethods = findMatchingMappingMethods(
      abstractMapper, targetField.type, returnType);
  if(matchingMappingMethods.isNotEmpty) {
    final nestedMappingMethod = matchingMappingMethods.first;

    if(
      nestedMappingMethod.parameters.first.type.nullabilitySuffix != NullabilitySuffix.question &&
      sourceFunction.returnType.nullabilitySuffix == NullabilitySuffix.question
    ) {
      final str = generateSafeCall(
        sourceFieldAssignment.accept(
          DartEmitter()
        ).toString(),
        nestedMappingMethod,
      );
      sourceFieldAssignment = refer(str);
    } else {
      sourceFieldAssignment = refer(matchingMappingMethods.first.name)
          .call([sourceFieldAssignment]);
    }
  }
  return sourceFieldAssignment;
}

/// Finds a matching Mapping Method in [classElement]
/// which has the same return type as the given [targetReturnType] and same parametertype as the given [sourceParameterType]
Iterable<MethodElement> findMatchingMappingMethods(ClassElement classElement,
    DartType targetReturnType, DartType sourceParameterType) {
  final matchingMappingMethods = classElement.methods.where((met) {
    // Sometimes the user is troubled by the nullability of these types.
    // So ingore the nullability of all the type for the nested mapping function is more easy to be matched.
    // The process of nullability is one duty for this library.

    if(met.parameters.isEmpty) {
        return false;
    }
    final metReturnElement = met.returnType.element;
    final metParameterElement = met.parameters.first.type.element;

    final targetReturnElement = targetReturnType.element;
    final srcParameterElement = sourceParameterType.element;

    return metReturnElement == targetReturnElement &&
        (metParameterElement == srcParameterElement);

    // return met.returnType == targetReturnType &&
    //     met.parameters.isNotEmpty && met.parameters.first.type == sourceParameterType;
  });
  return matchingMappingMethods;
}

generateSafeCall(
  String checkTarget,
  MethodElement method,
) {

  final methodInvoke = refer(method.name).call([refer("tmp")]).accept(DartEmitter()).toString();
  return '''
  (){
    final tmp = $checkTarget;
    return tmp == null ? null : $methodInvoke;
  }()
''';
}

Expression _generateNestedMapping(
  MethodElement method, 
  RefChain refChain,
) {
  if(method.parameters.first.isOptional) {
    // The parameter can be null.
    return refer(method.name)
        .call([refer(refChain.refWithQuestion)]);
  } else {
    return generateSafeExpression(
      refChain.isNullable,
      refer(refChain.refWithQuestion), 
      refer(method.name).call([refer(refChain.ref)])
    );
  }
}

// needCheck =  true => sourceRef == null ? null : expression
// needCheck = false => sourceRef
Expression generateSafeExpression(
  bool needCheck,
  Expression sourceRef,
  Expression expression,
) {
  if(needCheck) {
    return sourceRef.equalTo(literalNull).conditional(
      literalNull, 
      expression,
    );
  } else {
    return expression;
  }
}

